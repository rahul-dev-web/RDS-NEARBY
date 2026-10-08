import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantOffersScreen extends StatefulWidget {
  const MerchantOffersScreen({super.key, required this.businessId, required this.businessName});
  final String businessId;
  final String businessName;
  @override State<MerchantOffersScreen> createState() => _MerchantOffersScreenState();
}

class _MerchantOffersScreenState extends State<MerchantOffersScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _regularPrice = TextEditingController();
  final _offerPrice = TextEditingController();
  bool _saving = false, _loading = true;
  String? _error, _message;
  List<Map<String, dynamic>> _offers = [];
  Map<String, Map<String, dynamic>> _activeCampaigns = {};
  SupabaseClient get _client => Supabase.instance.client;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final offers = await _client.from('offers').select(
        'id,title,description,regular_price,offer_price,starts_at,ends_at,status',
      ).eq('business_id', widget.businessId).order('created_at', ascending: false);

      final campaigns = await _client.from('campaigns').select(
        'id,offer_id,ends_at,status,credit_cost',
      ).eq('business_id', widget.businessId).eq('campaign_type', 'promote_offer')
        .eq('status', 'active').gt('ends_at', DateTime.now().toUtc().toIso8601String());

      final active = <String, Map<String, dynamic>>{};
      for (final campaign in campaigns) {
        final offerId = campaign['offer_id']?.toString();
        if (offerId != null) active[offerId] = Map<String, dynamic>.from(campaign);
      }

      if (!mounted) return;
      setState(() {
        _offers = List<Map<String, dynamic>>.from(offers);
        _activeCampaigns = active;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load offers.'; });
    }
  }

  Future<void> _addOffer() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Enter an offer title.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    final now = DateTime.now().toUtc();
    try {
      await _client.from('offers').insert({
        'business_id': widget.businessId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'regular_price': double.tryParse(_regularPrice.text.trim()),
        'offer_price': double.tryParse(_offerPrice.text.trim()),
        'starts_at': now.toIso8601String(),
        'ends_at': now.add(const Duration(days: 7)).toIso8601String(),
        'status': 'active',
      });
      _title.clear(); _description.clear(); _regularPrice.clear(); _offerPrice.clear();
      if (!mounted) return;
      setState(() { _saving = false; _message = 'Offer created. It is active for 7 days.'; });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'Could not create offer. Check your business permissions.'; });
    }
  }

  Future<void> _promoteOffer(Map<String, dynamic> offer) async {
    final offerId = offer['id']?.toString();
    if (offerId == null) return;
    setState(() { _message = null; _error = null; });
    final key = 'offer_${offerId}_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    try {
      final response = await _client.functions.invoke('create-campaign', body: {
        'campaign_type': 'PROMOTE_OFFER',
        'business_id': widget.businessId,
        'offer_id': offerId,
        'idempotency_key': key,
      });
      final data = response.data;
      if (!mounted) return;
      setState(() {
        _message = data is Map && data['created'] == false
            ? 'This offer already has an active promotion.'
            : 'Offer promoted for the next 3 days.';
      });
      await _load();
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details?.toString() ?? '';
      setState(() {
        _error = details.contains('insufficient_marketing_credits')
            ? 'You need at least 100 Marketing Credits.'
            : details.contains('offer_not_active')
                ? 'This offer is not active anymore.'
                : details.contains('offer_not_owned')
                    ? 'This offer does not belong to this business.'
                    : 'Could not promote this offer right now.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not promote this offer right now.');
    }
  }

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override void dispose() {
    _title.dispose(); _description.dispose(); _regularPrice.dispose(); _offerPrice.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.businessName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Create a real customer offer, then spend 100 Marketing Credits to promote that specific offer for 3 days.'),
            const SizedBox(height: 18),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Create offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Offer title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _regularPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Regular price', prefixText: '₹ ', border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _offerPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Offer price', prefixText: '₹ ', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _saving ? null : _addOffer, icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.local_offer_outlined),
                  label: Text(_saving ? 'Creating...' : 'Create Offer')),
              ]),
            )),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 22),
            const Text('Your offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_offers.isEmpty) const Card(child: ListTile(leading: Icon(Icons.local_offer_outlined), title: Text('No offers yet'), subtitle: Text('Create your first offer above.')))
            else ..._offers.map((offer) {
              final id = offer['id']?.toString();
              final activeCampaign = id == null ? null : _activeCampaigns[id];
              final active = offer['status'] == 'active' &&
                  DateTime.tryParse(offer['ends_at']?.toString() ?? '')?.isAfter(DateTime.now().toUtc()) == true;
              return Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(offer['title']?.toString() ?? 'Offer', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if ((offer['description']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(offer['description'].toString())),
                  const SizedBox(height: 6),
                  Text('₹${offer['regular_price'] ?? '-'} → ₹${offer['offer_price'] ?? '-'} · ${_date(offer['starts_at']?.toString())}–${_date(offer['ends_at']?.toString())}'),
                  const SizedBox(height: 10),
                  if (activeCampaign != null)
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.campaign_outlined), title: const Text('Promote Offer is active'), subtitle: Text('Active until ${_date(activeCampaign['ends_at']?.toString())}'))
                  else
                    FilledButton.icon(onPressed: active ? () => _promoteOffer(offer) : null, icon: const Icon(Icons.campaign_outlined), label: const Text('Promote Offer · 100 credits')),
                ]),
              ));
            }),
          ],
        ),
      ),
    );
  }
}
