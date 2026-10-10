import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/referral_activity_service.dart';
import 'customer_referral_screen.dart';

class CustomerDiscoveryScreen extends StatefulWidget {
  const CustomerDiscoveryScreen({super.key});

  @override
  State<CustomerDiscoveryScreen> createState() => _CustomerDiscoveryScreenState();
}

class _CustomerDiscoveryScreenState extends State<CustomerDiscoveryScreen> {
  final _searchController = TextEditingController();
  final _localityController = TextEditingController();
  String? _categoryId;
  bool _openOnly = false;
  bool _availableOnly = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _businesses = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _todayItems = [];
  bool _todayLoading = false;
  String? _todayError;
  bool _todaySearched = false;

  SupabaseClient get _client => Supabase.instance.client;
  ReferralActivityService get _referralActivity => ReferralActivityService(_client);

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _search();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadTodaysNearYou() async {
    final locality = _localityController.text.trim();
    if (locality.isEmpty) {
      setState(() {
        _todayError = 'Enter your locality or nearby area to find local deals.';
        _todaySearched = false;
        _todayItems = [];
      });
      return;
    }
    setState(() { _todayLoading = true; _todayError = null; _todaySearched = true; });
    try {
      final response = await _client.rpc('get_todays_near_you', params: {
        'p_lat': null,
        'p_lng': null,
        'p_locality': locality,
        'p_limit': 30,
      });
      if (!mounted) return;
      setState(() {
        _todayItems = List<Map<String, dynamic>>.from(response as List);
        _todayLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayError = 'Today’s Near You is temporarily unavailable. Please try again.';
        _todayLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    final response = await _client
        .from('categories')
        .select('id,name,slug,icon')
        .eq('status', 'active')
        .order('sort_order');
    if (mounted) setState(() => _categories = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final query = _searchController.text.trim();
      var request = _client
          .from('businesses')
          .select('id,name,slug,description,phone,whatsapp,lat,lng,address,locality_id,category_id,accepting_requests,is_open,logo_url,categories(name,slug)')
          .eq('status', 'active')
          .eq('verification_status', 'verified');

      if (_categoryId != null) request = request.eq('category_id', _categoryId!);
      if (_openOnly) request = request.eq('is_open', true);

      if (query.isNotEmpty) {
        final escaped = query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
        final pattern = '%$escaped%';
        request = request.or('name.ilike.$pattern,description.ilike.$pattern,address.ilike.$pattern');
      }

      final rows = await request.order('is_open', ascending: false).limit(50);
      var businesses = List<Map<String, dynamic>>.from(rows);
      var offers = <Map<String, dynamic>>[];
      final now = DateTime.now().toUtc().toIso8601String();
      final boosts = await _client.from('campaigns')
          .select('business_id')
          .eq('campaign_type', 'boost_shop')
          .eq('status', 'active')
          .lte('starts_at', now)
          .gt('ends_at', now);
      final boostedIds = List<Map<String, dynamic>>.from(boosts)
          .map((campaign) => campaign['business_id'].toString()).toSet();
      final organic = businesses.where((business) => !boostedIds.contains(business['id'].toString())).toList();
      final sponsored = businesses.where((business) => boostedIds.contains(business['id'].toString())).toList();
      businesses = [];
      var organicIndex = 0;
      var sponsoredIndex = 0;
      while (organicIndex < organic.length || sponsoredIndex < sponsored.length) {
        for (var slot = 0; slot < 3 && organicIndex < organic.length; slot++) {
          businesses.add(organic[organicIndex++]);
        }
        if (sponsoredIndex < sponsored.length) {
          businesses.add(sponsored[sponsoredIndex++]);
        }
      }
      businesses = businesses.map((business) => {
        ...business,
        'is_sponsored': boostedIds.contains(business['id'].toString()),
      }).toList();

      // Search matching active offers independently. Promote Offer labels the offer only,
      // never the entire merchant's business card.
      if (query.isNotEmpty) {
        final offerEscaped = query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
        final pattern = '%$offerEscaped%';
        try {
          final offerRows = await _client.from('offers')
              .select('id,business_id,title,description,regular_price,offer_price,image_url,starts_at,ends_at,businesses(name,slug,address)')
              .eq('status', 'active')
              .lte('starts_at', now)
              .gt('ends_at', now)
              .or('title.ilike.$pattern,description.ilike.$pattern')
              .limit(30);
          offers = List<Map<String, dynamic>>.from(offerRows).map((offer) => {
            ...offer,
            'is_sponsored': false,
          }).toList();
          try {
            final campaignRows = await _client.from('campaigns')
                .select('offer_id')
                .eq('campaign_type', 'promote_offer')
                .eq('status', 'active')
                .lte('starts_at', now)
                .gt('ends_at', now)
                .not('offer_id', 'is', null);
            final promotedOfferIds = List<Map<String, dynamic>>.from(campaignRows)
                .map((campaign) => campaign['offer_id'].toString()).toSet();
            offers = offers.map((offer) => {
              ...offer,
              'is_sponsored': promotedOfferIds.contains(offer['id'].toString()),
            }).toList();
          } catch (_) {
            // Keep matching offers organic if campaign labels cannot be fetched.
          }
        } catch (_) {
          // Offer search is supplementary; keep valid shop results available on partial failure.
        }
      }

      var products = <Map<String, dynamic>>[];
      var services = <Map<String, dynamic>>[];
      if (query.isNotEmpty) {
        final inventoryEscaped = query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
        final inventoryPattern = '%$inventoryEscaped%';
        try {
          final rows = await _client.from('business_products')
              .select('id,business_id,name,description,price,unit,businesses(name,slug,address)')
              .eq('status', 'active').eq('is_available', true)
              .or('name.ilike.$inventoryPattern,description.ilike.$inventoryPattern')
              .limit(30);
          products = List<Map<String, dynamic>>.from(rows);
        } catch (_) {
          // Product inventory is supplementary; shop and offer results remain usable.
        }
        try {
          final rows = await _client.from('business_services')
              .select('id,business_id,name,description,price,duration_minutes,businesses(name,slug,address)')
              .eq('status', 'active').eq('is_available', true)
              .or('name.ilike.$inventoryPattern,description.ilike.$inventoryPattern')
              .limit(30);
          services = List<Map<String, dynamic>>.from(rows);
        } catch (_) {
          // Service inventory is supplementary; shop and offer results remain usable.
        }
      }

      if (_availableOnly) {
        final ids = businesses.map((row) => row['id'].toString()).toList();
        if (ids.isNotEmpty) {
          final products = await _client.from('business_products').select('business_id').inFilter('business_id', ids).eq('is_available', true).eq('status', 'active');
          final services = await _client.from('business_services').select('business_id').inFilter('business_id', ids).eq('is_available', true).eq('status', 'active');
          final availableIds = {
            ...List<Map<String, dynamic>>.from(products).map((row) => row['business_id'].toString()),
            ...List<Map<String, dynamic>>.from(services).map((row) => row['business_id'].toString()),
          };
          businesses = businesses.where((row) => availableIds.contains(row['id'].toString())).toList();
        } else {
          businesses = [];
        }
      }

      if (mounted) setState(() { _businesses = businesses; _offers = offers; _products = products; _services = services; _loading = false; });
      await _referralActivity.recordMeaningfulActivity('SEARCH');
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load nearby businesses.'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby'),
        actions: [
          IconButton(
            tooltip: 'Local Points & Referral',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerReferralScreen()),
            ),
            icon: const Icon(Icons.stars_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('What do you need?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Find products, services and shops around you.'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🔥 Today’s Near You', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Today’s active offers and promoted shops in your locality.'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _localityController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _loadTodaysNearYou(),
                      decoration: const InputDecoration(
                        hintText: 'Enter locality / area',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    )),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _todayLoading ? null : _loadTodaysNearYou,
                      child: _todayLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Find'),
                    ),
                  ]),
                  if (_todayError != null) ...[
                    const SizedBox(height: 8),
                    Text(_todayError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_todaySearched && !_todayLoading && _todayError == null && _todayItems.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('No active offers or promoted shops were found for this locality yet. Try a nearby area.'),
                  ],
                  if (_todayItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._todayItems.map((item) => _TodayNearYouCard(item: item)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'A4 sheet, tomato, haircut, charger...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            if (_categories.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) return ChoiceChip(label: const Text('All'), selected: _categoryId == null, onSelected: (_) { setState(() => _categoryId = null); _search(); });
                    final category = _categories[index - 1];
                    return ChoiceChip(label: Text(category['name']?.toString() ?? 'Category'), selected: _categoryId == category['id']?.toString(), onSelected: (_) { setState(() => _categoryId = category['id']?.toString()); _search(); });
                  },
                ),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilterChip(label: const Text('Open now'), selected: _openOnly, onSelected: (value) { setState(() => _openOnly = value); _search(); }),
              FilterChip(label: const Text('Available'), selected: _availableOnly, onSelected: (value) { setState(() => _availableOnly = value); _search(); }),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text(_searchController.text.trim().isEmpty ? 'Nearby businesses' : 'Search results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 10),
            if (_error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_error!), trailing: TextButton(onPressed: _search, child: const Text('Retry')))),
            if (!_loading && _error == null && _businesses.isEmpty && _offers.isEmpty && _products.isEmpty && _services.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching shops or active offers yet. Try another search or category.'))),
            if (_products.isNotEmpty) ...[
              Text('Matching products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._products.map((product) => _InventoryCard(item: product, isService: false)),
              const SizedBox(height: 8),
            ],
            if (_services.isNotEmpty) ...[
              Text('Matching services', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._services.map((service) => _InventoryCard(item: service, isService: true)),
              const SizedBox(height: 8),
            ],
            if (_offers.isNotEmpty) ...[
              Text('Matching offers', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._offers.map((offer) => _OfferCard(offer: offer)),
              const SizedBox(height: 8),
            ],
            if (_businesses.isNotEmpty) ...[
              Text('Matching shops', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._businesses.map((business) => _BusinessCard(business: business)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _phoneUri(String value) {
    final digits = _digits(value);
    return digits.length == 10 ? '+91$digits' : '+$digits';
  }

  String _whatsappUri(String value) {
    final digits = _digits(value);
    return digits.length == 10 ? '91$digits' : digits;
  }

  Future<void> _launch(BuildContext context, Uri uri, String failureMessage) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _sendCustomerRequest(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var requestType = 'availability';
    final form = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send a Customer Request'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: requestType,
                decoration: const InputDecoration(labelText: 'Request type'),
                items: const [
                  DropdownMenuItem(value: 'availability', child: Text('Check availability')),
                  DropdownMenuItem(value: 'contact', child: Text('Contact the shop')),
                  DropdownMenuItem(value: 'reserve', child: Text('Reservation request')),
                ],
                onChanged: (value) { if (value != null) setDialogState(() => requestType = value); },
              ),
              TextField(
                controller: titleController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'What do you need?', hintText: 'e.g. Is this available today?'),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
              const SizedBox(height: 8),
              const Text('The request expires after 10 minutes if the shop does not respond.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'request_type': requestType,
                  'title': title,
                  'description': descriptionController.text.trim(),
                });
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    if (form == null || !context.mounted) return;

    try {
      await Supabase.instance.client.rpc('create_customer_request', params: {
        'p_business_id': business['id'].toString(),
        'p_request_type': form['request_type'],
        'p_title': form['title'],
        'p_description': (form['description'] ?? '').isEmpty ? null : form['description'],
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent. The shop has up to 10 minutes to respond.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request could not be sent. The shop may no longer be accepting requests.')));
    }
  }

  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) {
    final category = business['categories'] is Map ? (business['categories'] as Map)['name']?.toString() : null;
    final open = business['is_open'] == true;
    final accepting = business['accepting_requests'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Text((business['name']?.toString() ?? 'S').substring(0, 1).toUpperCase())),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(business['name']?.toString() ?? 'Business', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (business['is_sponsored'] == true) const Text('SPONSORED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              if (category != null) Text(category, style: Theme.of(context).textTheme.bodySmall),
            ])),
            Chip(label: Text(open ? 'Open' : 'Closed')),
          ]),
          if ((business['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10), Text(business['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if ((business['address']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8), Row(children: [Icon(Icons.location_on_outlined, size: 17), SizedBox(width: 4), Expanded(child: Text(business['address'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis))]),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (business['phone'] != null && business['phone'].toString().trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _launch(context, Uri(scheme: 'tel', path: _phoneUri(business['phone'].toString())), 'Could not open the phone app.'),
                  icon: const Icon(Icons.call, size: 17),
                  label: const Text('Call'),
                ),
              if (business['whatsapp'] != null && business['whatsapp'].toString().trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _launch(context, Uri.parse('https://wa.me/' + _whatsappUri(business['whatsapp'].toString())), 'Could not open WhatsApp.'),
                  icon: const Icon(Icons.chat, size: 17),
                  label: const Text('WhatsApp'),
                ),
              if (business['lat'] != null && business['lng'] != null)
                OutlinedButton.icon(
                  onPressed: () => _launch(context, Uri.parse('https://www.google.com/maps/search/?api=1&query=' + Uri.encodeComponent(business['lat'].toString() + ',' + business['lng'].toString())), 'Could not open directions.'),
                  icon: const Icon(Icons.directions, size: 17),
                  label: const Text('Directions'),
                ),
              if (accepting) ...[
                const Chip(label: Text('Accepting Requests'), avatar: Icon(Icons.check_circle_outline, size: 16)),
                OutlinedButton.icon(
                  onPressed: () => _sendCustomerRequest(context),
                  icon: const Icon(Icons.mark_chat_unread_outlined, size: 17),
                  label: const Text('Request'),
                ),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}


class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.isService});

  final Map<String, dynamic> item;
  final bool isService;

  @override
  Widget build(BuildContext context) {
    final business = item['businesses'] is Map
        ? Map<String, dynamic>.from(item['businesses'] as Map)
        : <String, dynamic>{};
    final price = item['price'];
    final unit = item['unit']?.toString();
    final duration = item['duration_minutes'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(item['name']?.toString() ?? (isService ? 'Service' : 'Product'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Chip(label: Text(isService ? 'Service' : 'Product')),
          ]),
          if ((item['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          if (price != null || (isService && duration != null))
            Wrap(spacing: 8, children: [
              if (price != null) Text('₹' + price.toString() + (!isService && unit != null && unit.isNotEmpty ? ' / ' + unit : ''), style: const TextStyle(fontWeight: FontWeight.w800)),
              if (isService && duration != null) Text(duration.toString() + ' min', style: Theme.of(context).textTheme.bodySmall),
            ])
          else
            const Text('Ask shop for price'),
          const SizedBox(height: 6),
          Text(business['name']?.toString() ?? 'Local business', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if ((business['address']?.toString() ?? '').isNotEmpty)
            Text(business['address'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context) {
    final business = offer['businesses'] is Map
        ? Map<String, dynamic>.from(offer['businesses'] as Map)
        : <String, dynamic>{};
    final offerPrice = offer['offer_price'];
    final regularPrice = offer['regular_price'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_offer_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(offer['title']?.toString() ?? 'Offer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            if (offer['is_sponsored'] == true)
              const Chip(label: Text('SPONSORED', style: TextStyle(fontSize: 10))),
          ]),
          if ((offer['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(offer['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          if (offerPrice != null)
            Row(children: [
              Text('₹$offerPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (regularPrice != null) ...[
                const SizedBox(width: 8),
                Text('₹$regularPrice', style: const TextStyle(decoration: TextDecoration.lineThrough)),
              ],
            ]),
          const SizedBox(height: 6),
          Text(business['name']?.toString() ?? 'Local shop', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if ((business['address']?.toString() ?? '').isNotEmpty)
            Text(business['address'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
