import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';

class CustomerReferralScreen extends StatefulWidget {
  const CustomerReferralScreen({super.key});

  @override
  State<CustomerReferralScreen> createState() => _CustomerReferralScreenState();
}

class _CustomerReferralScreenState extends State<CustomerReferralScreen> {
  bool _loading = true;
  bool _redeeming = false;
  String? _token;
  String? _error;
  String? _redemptionMessage;
  int _points = 0;
  List<Map<String, dynamic>> _rewardBusinesses = [];
  String? _selectedBusinessId;
  final _billController = TextEditingController();
  final _pointsController = TextEditingController();
  String? _pendingIdempotencyKey;

  SupabaseClient get _client => Supabase.instance.client;

  String get _publicWebUrl => AppConfig.publicWebUrl.trim().replaceFirst(RegExp(r'/$'), '');
  String get _referralUrl => '$_publicWebUrl/r/$_token';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _error = 'Sign in to view Local Points.'; _loading = false; });
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        _client.from('customer_wallets')
            .select('balance')
            .eq('customer_id', user.id)
            .maybeSingle(),
        _client.from('businesses')
            .select('id,name,rewards_min_bill,rewards_max_discount')
            .eq('status', 'active')
            .eq('verification_status', 'verified')
            .eq('local_rewards_enabled', true)
            .order('name')
            .limit(100),
      ]);

      final wallet = results[0] as Map<String, dynamic>?;
      final businesses = List<Map<String, dynamic>>.from(results[1] as List);
      String? token;
      String? referralError;

      if (_publicWebUrl.isNotEmpty) {
        try {
          final result = await _client.functions.invoke('create-customer-referral');
          final data = Map<String, dynamic>.from(result.data as Map);
          final value = data['token']?.toString().trim();
          if (value != null && value.isNotEmpty) token = value;
        } catch (_) {
          referralError = 'Referral link is temporarily unavailable.';
        }
      } else {
        referralError = 'Public web URL is not configured for referral links.';
      }

      if (!mounted) return;
      setState(() {
        _points = (wallet?['balance'] as num?)?.toInt() ?? 0;
        _rewardBusinesses = businesses;
        _selectedBusinessId = businesses.any((b) => b['id'].toString() == _selectedBusinessId)
            ? _selectedBusinessId
            : (businesses.isNotEmpty ? businesses.first['id'].toString() : null);
        _token = token;
        _error = referralError;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your Local Points and nearby rewards.'; _loading = false; });
    }
  }

  Future<void> _copy() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _referralUrl));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
  }

  Future<void> _redeem() async {
    final businessId = _selectedBusinessId;
    final bill = double.tryParse(_billController.text.trim());
    final requestedPoints = int.tryParse(_pointsController.text.trim());
    if (businessId == null) {
      setState(() => _redemptionMessage = 'Choose a shop that participates in Local Rewards.');
      return;
    }
    if (bill == null || !bill.isFinite || bill <= 0) {
      setState(() => _redemptionMessage = 'Enter a valid bill amount greater than ₹0.');
      return;
    }
    if (requestedPoints == null || requestedPoints <= 0) {
      setState(() => _redemptionMessage = 'Enter how many Local Points you want to use.');
      return;
    }
    if (requestedPoints > _points) {
      setState(() => _redemptionMessage = 'You do not have enough Local Points.');
      return;
    }

    final idempotencyKey = _pendingIdempotencyKey ??=
        'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    setState(() { _redeeming = true; _redemptionMessage = null; });
    try {
      final response = await _client.rpc('redeem_customer_points', params: {
        'p_business_id': businessId,
        'p_bill_amount': bill,
        'p_points_to_redeem': requestedPoints,
        'p_idempotency_key': idempotencyKey,
      });
      final result = Map<String, dynamic>.from(response as Map);
      final used = (result['points_used'] as num).toInt();
      final discount = (result['discount_value'] as num).toDouble();
      final finalAmount = (result['final_amount'] as num).toDouble();
      final balance = (result['balance_after'] as num).toInt();
      final redemptionId = result['redemption_id'].toString();

      if (!mounted) return;
      setState(() {
        _points = balance;
        _redeeming = false;
        _pendingIdempotencyKey = null;
        _redemptionMessage = 'Redemption created. Show the redemption code to the shop. '
            'Points used: $used · Discount: ₹${discount.toStringAsFixed(2)} · '
            'Pay: ₹${finalAmount.toStringAsFixed(2)}';
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Local Points redemption'),
          content: SelectableText(
            'Redemption code\n$redemptionId\n\n'
            'Points used: $used\n'
            'Discount: ₹${discount.toStringAsFixed(2)}\n'
            'Final bill: ₹${finalAmount.toStringAsFixed(2)}\n\n'
            'Show this code to the shop. The redemption is pending merchant confirmation.',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Keep the same idempotency key after an uncertain network failure so a retry
      // cannot deduct points twice if the first server transaction already committed.
      setState(() {
        _redeeming = false;
        _redemptionMessage = 'Redemption could not be confirmed. Retry safely or check your balance. Details: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _billController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Points & Referral')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.stars_outlined),
                      title: const Text('Local Points'),
                      subtitle: const Text('100 points = ₹10 reward value. Points are non-cash.'),
                      trailing: Text('$_points', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Redeem Local Points', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Choose a participating shop, enter your bill and points. The shop sets the minimum bill and maximum discount.'),
                  const SizedBox(height: 12),
                  if (_rewardBusinesses.isEmpty)
                    const Card(child: ListTile(leading: Icon(Icons.storefront_outlined), title: Text('No participating shops yet'), subtitle: Text('Local Rewards will appear here when eligible shops enable and configure them.')))
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedBusinessId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Participating shop', border: OutlineInputBorder()),
                      items: _rewardBusinesses.map((business) => DropdownMenuItem<String>(
                        value: business['id'].toString(),
                        child: Text(business['name']?.toString() ?? 'Shop', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: _redeeming ? null : (value) => setState(() { _selectedBusinessId = value; _redemptionMessage = null; }),
                    ),
                    if (_selectedBusinessId != null) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        final business = _rewardBusinesses.firstWhere((b) => b['id'].toString() == _selectedBusinessId);
                        final minBill = business['rewards_min_bill'];
                        final maxDiscount = business['rewards_max_discount'];
                        return Text(
                          'Minimum bill: ₹${minBill ?? '—'} · Maximum discount: ₹${maxDiscount ?? '—'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _billController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: const InputDecoration(labelText: 'Bill amount', prefixText: '₹ ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: 'Points to use (available: $_points)', border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _redeeming || _points <= 0 ? null : _redeem,
                      icon: const Icon(Icons.redeem),
                      label: Text(_redeeming ? 'Creating redemption…' : 'Redeem Points'),
                    ),
                    if (_redemptionMessage != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(_redemptionMessage!),
                    ],
                  ],
                  const Divider(height: 36),
                  const Text('Invite a friend', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Your friend must verify, complete onboarding and perform meaningful activity within 48 hours. Then you earn 10 Local Points.'),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(_error!))),
                  if (_token != null) ...[
                    Center(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: QrImageView(data: _referralUrl, version: QrVersions.auto, size: 240),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(_referralUrl, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('Copy Referral Link')),
                  ],
                ],
              ),
            ),
    );
  }
}
