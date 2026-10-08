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
  String? _error;
  int _balance = 0;
  List<Map<String, dynamic>> _ledger = [];

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

      if (!mounted) return;
      setState(() {
        _balance = (wallet?['balance'] as num?)?.toInt() ?? 0;
        _ledger = List<Map<String, dynamic>>.from(ledger);
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

  @override
  Widget build(BuildContext context) {
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
