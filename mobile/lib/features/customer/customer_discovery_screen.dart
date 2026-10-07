import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerDiscoveryScreen extends StatefulWidget {
  const CustomerDiscoveryScreen({super.key});

  @override
  State<CustomerDiscoveryScreen> createState() => _CustomerDiscoveryScreenState();
}

class _CustomerDiscoveryScreenState extends State<CustomerDiscoveryScreen> {
  final _searchController = TextEditingController();
  String? _categoryId;
  bool _openOnly = false;
  bool _availableOnly = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _businesses = [];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _search();
    _searchController.addListener(_onSearchChanged);
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
        request = request.or('name.ilike.%$query%,description.ilike.%$query%,address.ilike.%$query%');
      }

      final rows = await request.order('is_open', ascending: false).limit(50);
      var businesses = List<Map<String, dynamic>>.from(rows);

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

      if (mounted) setState(() { _businesses = businesses; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load nearby businesses.'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('What do you need?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Find products, services and shops around you.'),
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
            if (!_loading && _error == null && _businesses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching shops yet. Try another search or category.'))),
            ..._businesses.map((business) => _BusinessCard(business: business)),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business});

  void _copyContact(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          Row(children: [
            if (business['phone'] != null) OutlinedButton.icon(onPressed: () => _copyContact(context, business['phone'].toString(), 'Phone number copied'), icon: const Icon(Icons.call, size: 17), label: const Text('Call')),
            const SizedBox(width: 8),
            if (business['whatsapp'] != null) OutlinedButton.icon(onPressed: () => _copyContact(context, business['whatsapp'].toString(), 'WhatsApp number copied'), icon: const Icon(Icons.chat, size: 17), label: const Text('WhatsApp')),
            const Spacer(),
            if (accepting) const Text('Accepting Requests', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}
