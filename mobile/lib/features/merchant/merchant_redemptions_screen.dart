import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantRedemptionsScreen extends StatefulWidget {
  const MerchantRedemptionsScreen({
    required this.businessId,
    required this.businessName,
    super.key,
  });

  final String businessId;
  final String businessName;

  @override
  State<MerchantRedemptionsScreen> createState() => _MerchantRedemptionsScreenState();
}

class _MerchantRedemptionsScreenState extends State<MerchantRedemptionsScreen> {
  bool _loading = true;
  String? _error;
  String? _actingId;
  List<Map<String, dynamic>> _redemptions = [];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _client
          .from('redemptions')
          .select('id,customer_id,points_used,discount_value,bill_amount,final_amount,status,created_at')
          .eq('business_id', widget.businessId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _redemptions = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load pending redemptions. Check business access and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _respond(Map<String, dynamic> redemption, String action) async {
    final id = redemption['id'].toString();
    setState(() { _actingId = id; _error = null; });
    try {
      await _client.rpc('respond_to_point_redemption', params: {
        'p_redemption_id': id,
        'p_action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == 'approve'
            ? 'Redemption approved. Apply the displayed discount to the bill.'
            : 'Redemption rejected and Local Points refunded.'),
      ));
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = action == 'approve'
            ? 'Could not approve this redemption. It may already be resolved.'
            : 'Could not reject this redemption. No refund was confirmed.';
      });
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Points Redemptions'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.businessName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('Confirm the redemption code before applying a discount. Reject invalid codes to refund the customer automatically.'),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  if (_redemptions.isEmpty)
                    const Card(child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('No pending redemptions'),
                      subtitle: Text('New Local Points redemption requests will appear here.'),
                    )),
                  ..._redemptions.map((item) {
                    final id = item['id'].toString();
                    final isActing = _actingId == id;
                    final code = id.length > 12 ? id.substring(0, 12).toUpperCase() : id.toUpperCase();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Code: $code…', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            SelectableText('Full code: $id', style: Theme.of(context).textTheme.bodySmall),
                            const Divider(),
                            Text('Customer: ${item['customer_id']}'),
                            Text('Bill: ₹${item['bill_amount']}'),
                            Text('Discount requested: ₹${item['discount_value']}'),
                            Text('Final amount: ₹${item['final_amount']}'),
                            Text('Points to deduct: ${item['points_used']}'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(
                                  onPressed: isActing || _actingId != null ? null : () => _respond(item, 'reject'),
                                  child: Text(isActing ? 'Working…' : 'Reject & refund'),
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: FilledButton(
                                  onPressed: isActing || _actingId != null ? null : () => _respond(item, 'approve'),
                                  child: const Text('Approve'),
                                )),
                              ],
                            ),
                          ],
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
