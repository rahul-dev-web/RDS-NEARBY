import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCreditWalletScreen extends StatefulWidget {
  const MerchantCreditWalletScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<MerchantCreditWalletScreen> createState() =>
      _MerchantCreditWalletScreenState();
}

class _MerchantCreditWalletScreenState
    extends State<MerchantCreditWalletScreen> {
  bool _loading = true;
  bool _creatingBoost = false;
  String? _error;
  String? _boostMessage;
  int _balance = 0;
  List<Map<String, dynamic>> _ledger = [];
  Map<String, dynamic>? _activeBoost;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final wallet = await _client
          .from('merchant_wallets')
          .select('balance,updated_at')
          .eq('merchant_id', widget.businessId)
          .maybeSingle();

      final ledger = await _client
          .from('merchant_credit_ledger')
          .select(
            'amount,transaction_type,balance_after,created_at,reference_id',
          )
          .eq('merchant_id', widget.businessId)
          .order('created_at', ascending: false)
          .limit(50);

      final campaigns = await _client
          .from('campaigns')
          .select(
            'id,campaign_type,credit_cost,starts_at,ends_at,status,target_radius_km',
          )
          .eq('business_id', widget.businessId)
          .eq('campaign_type', 'BOOST_SHOP')
          .eq('status', 'ACTIVE')
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('ends_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      setState(() {
        _balance = (wallet?['balance'] as num?)?.toInt() ?? 0;
        _ledger = List<Map<String, dynamic>>.from(ledger);
        _activeBoost = campaigns.isEmpty
            ? null
            : Map<String, dynamic>.from(campaigns.first);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Marketing Credits.';
        _loading = false;
      });
    }
  }

  Future<void> _boostShop() async {
    if (_creatingBoost) return;

    setState(() {
      _creatingBoost = true;
      _boostMessage = null;
    });

    final key =
        'boost_${widget.businessId}_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

    try {
      final response = await _client.functions.invoke(
        'create-campaign',
        body: {
          'campaign_type': 'BOOST_SHOP',
          'business_id': widget.businessId,
          'idempotency_key': key,
        },
      );

      final data = response.data;
      if (data is Map && data['created'] == false) {
        final reason = data['reason']?.toString();
        if (reason == 'active_campaign_exists') {
          _boostMessage = 'Boost Shop is already active for this business.';
        } else {
          _boostMessage = 'This Boost Shop request was already processed.';
        }
      } else {
        _boostMessage = 'Boost Shop is active for the next 24 hours.';
      }

      if (!mounted) return;
      setState(() {
        _creatingBoost = false;
      });
      await _loadWallet();
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details?.toString() ?? '';
      final reason = details.contains('insufficient_marketing_credits')
          ? 'You need at least 50 Marketing Credits.'
          : 'Could not activate Boost Shop right now.';
      setState(() {
        _creatingBoost = false;
        _boostMessage = reason;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creatingBoost = false;
        _boostMessage = 'Could not activate Boost Shop right now.';
      });
    }
  }

  String _label(String value) {
    switch (value) {
      case 'REFERRAL_REWARD':
        return 'Qualified referral';
      case 'BOOST_SPEND':
        return 'Boost Shop';
      case 'PROMOTE_OFFER_SPEND':
        return 'Promote Offer';
      case 'ADMIN_ADJUSTMENT':
        return 'Account adjustment';
      case 'REVERSAL':
        return 'Reversal';
      default:
        return value;
    }
  }

  String _formatEndsAt(String? value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    return 'Active until ${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final canBoost = !_loading && !_creatingBoost && _balance >= 50;
    final active = _activeBoost != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Credits'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadWallet,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.businessName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Marketing Credits'),
                    const SizedBox(height: 8),
                    Text(
                      '$_balance',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Credits do not expire. Maximum balance: 2,000.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Boost Shop',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use 50 Marketing Credits to promote your shop for 24 hours.',
                    ),
                    const SizedBox(height: 14),
                    if (active)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text('Boost Shop is active'),
                        subtitle: Text(_formatEndsAt(_activeBoost?['ends_at'])),
                      )
                    else
                      FilledButton.icon(
                        onPressed: canBoost ? _boostShop : null,
                        icon: _creatingBoost
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.rocket_launch_outlined),
                        label: Text(
                          _creatingBoost
                              ? 'Activating...'
                              : 'Boost Shop · 50 credits',
                        ),
                      ),
                    if (!active && _balance < 50 && !_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Earn more Marketing Credits through qualified customer referrals.',
                        ),
                      ),
                    if (_boostMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _boostMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'How you earn and spend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_add_alt_1_outlined),
                    title: Text('+10 credits'),
                    subtitle: Text('Per qualified customer referral'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.storefront_outlined),
                    title: Text('50 credits'),
                    subtitle: Text('Boost Shop for 24 hours'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.local_offer_outlined),
                    title: Text('100 credits'),
                    subtitle: Text('Promote Offer for 3 days'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  trailing: IconButton(
                    onPressed: _loadWallet,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_ledger.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('No credit activity yet'),
                  subtitle: Text(
                    'Qualified referrals will appear here automatically.',
                  ),
                ),
              )
            else
              ..._ledger.map((entry) {
                final amount = (entry['amount'] as num?)?.toInt() ?? 0;
                final type = entry['transaction_type']?.toString() ?? '';
                final balanceAfter =
                    (entry['balance_after'] as num?)?.toInt() ?? 0;
                final positive = amount >= 0;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      positive
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(_label(type)),
                    subtitle: Text('Balance after: $balanceAfter'),
                    trailing: Text(
                      (positive ? '+' : '') + amount.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: positive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
