import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Merchant membership visibility for the pilot.
///
/// Payment and subscription mutations intentionally remain disabled until
/// pilot evidence and a payment provider have been approved. This screen
/// reads the authoritative membership state; it never manufactures a paid
/// subscription or changes membership rows from the client.
class MerchantMembershipScreen extends StatefulWidget {
  const MerchantMembershipScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<MerchantMembershipScreen> createState() =>
      _MerchantMembershipScreenState();
}

class _MerchantMembershipScreenState extends State<MerchantMembershipScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _membership;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _client
          .from('memberships')
          .select(
            'plan,status,started_at,expires_at,provider,created_at,updated_at',
          )
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;
      setState(() {
        final memberships = List<Map<String, dynamic>>.from(rows);
        _membership = memberships.isEmpty ? null : memberships.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Membership details could not be loaded. Check your connection and business access.';
        _loading = false;
      });
    }
  }

  String get _plan {
    final value = _membership?['plan']?.toString().toLowerCase();
    return value == 'growth' ? 'Local Business Growth' : 'Basic';
  }

  String get _status {
    final value = _membership?['status']?.toString().toLowerCase();
    if (value == null || value.isEmpty) return 'not_started';
    return value;
  }

  String _prettyStatus(String value) {
    switch (value) {
      case 'active':
        return 'Active';
      case 'trial':
        return 'Pilot / trial';
      case 'past_due':
        return 'Payment due';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      case 'not_started':
        return 'Basic access';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  String? _formatDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return null;
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final growth = _membership?['plan']?.toString().toLowerCase() == 'growth';
    final expiresAt = _formatDate(_membership?['expires_at']);
    final startedAt = _formatDate(_membership?['started_at']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership'),
        actions: [
          IconButton(
            tooltip: 'Refresh membership',
            onPressed: _loading ? null : _loadMembership,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMembership,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.businessName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Membership & access',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Could not load membership'),
                            const SizedBox(height: 8),
                            Text(_error!),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loadMembership,
                                child: const Text('Try again'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Icon(
                                    growth
                                        ? Icons.trending_up
                                        : Icons.storefront_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _plan,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Chip(label: Text(_prettyStatus(_status))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              growth ? '₹99 / month' : '₹0 · Free',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (startedAt != null) ...[
                              const SizedBox(height: 8),
                              Text('Started: $startedAt'),
                            ],
                            if (expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text('Valid until: $expiresAt'),
                            ],
                            const SizedBox(height: 12),
                            const Text(
                              'This screen shows the membership state saved by '
                              'the platform. Billing is not enabled in the pilot.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Basic · ₹0',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _MembershipBenefit(
                      text: 'Basic business profile and organic listing',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Local Business Growth · ₹99/month',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _MembershipBenefit(text: 'Customer referral QR'),
                    const _MembershipBenefit(text: 'Marketing Credits'),
                    const _MembershipBenefit(text: 'Boost Shop and Promote Offer'),
                    const _MembershipBenefit(text: 'Offers and Customer Requests'),
                    const _MembershipBenefit(text: 'Business analytics'),
                    const _MembershipBenefit(text: 'Local Points participation'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline),
                      label: Text(
                        growth ? 'Billing unavailable during pilot' : 'Growth plan coming after pilot',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paid activation stays disabled until the pilot demonstrates '
                      'measurable customer value and a payment provider is configured. '
                      'No payment will be collected from this screen.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MembershipBenefit extends StatelessWidget {
  const _MembershipBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
