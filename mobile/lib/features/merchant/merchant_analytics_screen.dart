import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantAnalyticsScreen extends StatefulWidget {
  const MerchantAnalyticsScreen({super.key, required this.businessId, required this.businessName});
  final String businessId;
  final String businessName;

  @override
  State<MerchantAnalyticsScreen> createState() => _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState extends State<MerchantAnalyticsScreen> {
  final _client = Supabase.instance.client;
  Map<String, dynamic> _metrics = <String, dynamic>{};
  bool _loading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _client.rpc('get_merchant_business_analytics', params: {
        'p_business_id': widget.businessId,
        'p_days': _days,
      });
      if (!mounted) return;
      setState(() { _metrics = Map<String, dynamic>.from(result as Map); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Analytics could not be loaded. Check business access and try again.'; _loading = false; });
    }
  }

  String _value(String key, {bool currency = false}) {
    final raw = _metrics[key];
    if (raw == null) return currency ? '₹0.00' : '0';
    final number = raw is num ? raw : num.tryParse(raw.toString()) ?? 0;
    return currency ? '₹${number.toStringAsFixed(2)}' : number.toString();
  }

  Widget _metric(String title, String key, IconData icon, {bool currency = false}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22),
        const SizedBox(height: 10),
        Text(_value(key, currency: currency), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Analytics'), actions: [
      IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
    ]),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.businessName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Understand customer actions and marketing value—not just impressions.'),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
          ],
          selected: <int>{_days},
          onSelectionChanged: (selection) { setState(() => _days = selection.first); _load(); },
        ),
        if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
          Center(child: TextButton(onPressed: _load, child: const Text('Try again'))),
        ],
        if (!_loading && _error == null) ...[
          const SizedBox(height: 12),
          Text('Customer activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.55, children: [
            _metric('Shop views', 'shop_views', Icons.storefront_outlined),
            _metric('Search result clicks', 'search_matches', Icons.search),
            _metric('Offers viewed', 'offers_viewed', Icons.local_offer_outlined),
            _metric('Offer claims', 'offers_claimed', Icons.sell_outlined),
            _metric('Call clicks', 'call_clicks', Icons.call_outlined),
            _metric('WhatsApp clicks', 'whatsapp_clicks', Icons.chat_outlined),
            _metric('Shop saves', 'saved_count', Icons.bookmark_border),
            _metric('Requests received', 'requests_received', Icons.inbox_outlined),
            _metric('Requests responded', 'requests_responded', Icons.mark_chat_read_outlined),
            _metric('New referral customers', 'new_referral_customers', Icons.person_add_alt_1),
          ]),
          const SizedBox(height: 8),
          Text('Marketing value', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.55, children: [
            _metric('Credits earned', 'credits_earned', Icons.add_circle_outline),
            _metric('Credits spent', 'credits_spent', Icons.remove_circle_outline),
            _metric('Current credits', 'current_marketing_credits', Icons.account_balance_wallet_outlined),
            _metric('Boost Shop campaigns', 'boost_campaigns_created', Icons.campaign_outlined),
            _metric('Promote Offer campaigns', 'promoted_offers_created', Icons.local_offer_outlined),
            _metric('Approved redemptions', 'redemptions_approved', Icons.redeem_outlined),
            _metric('Merchant-funded discounts', 'redemption_discount_total', Icons.currency_rupee, currency: true),
          ]),
          const SizedBox(height: 8),
          Text('Period: last $_days days. Metrics combine recorded events and transaction tables. Customer identities are not shown.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    ),
  );
}
