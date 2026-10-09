import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantRequestsScreen extends StatefulWidget {
  const MerchantRequestsScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    this.initialRequestId,
  });

  final String businessId;
  final String businessName;
  final String? initialRequestId;

  @override
  State<MerchantRequestsScreen> createState() => _MerchantRequestsScreenState();
}

class _MerchantRequestsScreenState extends State<MerchantRequestsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  final Set<String> _busyIds = <String>{};
  bool _initialRequestHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _client
          .from('customer_requests')
          .select('id,customer_id,request_type,title,description,status,created_at,expires_at,updated_at')
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
      _showInitialRequestIfPresent();
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = 'Could not load requests. Check your connection and business access.'; _loading = false; });
    }
  }

  void _showInitialRequestIfPresent() {
    final targetId = widget.initialRequestId;
    if (_initialRequestHandled || targetId == null) return;

    Map<String, dynamic>? target;
    for (final request in _requests) {
      if (request['id']?.toString() == targetId) {
        target = request;
        break;
      }
    }
    if (target == null) return;

    _initialRequestHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final request = target!;
      final description = request['description']?.toString() ?? '';
      final status = request['status']?.toString() ?? 'pending';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(request['title']?.toString() ?? 'Customer Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${status.toUpperCase()}'),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            if (status == 'pending') ...[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _respond(request, 'decline');
                },
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _respond(request, 'accept');
                },
                child: const Text('Accept'),
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _respond(Map<String, dynamic> request, String decision) async {
    final id = request['id']?.toString() ?? '';
    if (id.isEmpty || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      final result = await _client.rpc('respond_customer_request', params: {
        'p_request_id': id,
        'p_decision': decision,
        'p_message': null,
        'p_price': null,
      });
      if (!mounted) return;
      final status = result?.toString() ?? (decision == 'accept' ? 'accepted' : 'declined');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'expired'
            ? 'This request has expired.'
            : decision == 'accept' ? 'Request accepted.' : 'Request declined.')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this request. It may have expired or already been handled.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Requests'),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(children: [const SizedBox(height: 100), Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))), Center(child: TextButton(onPressed: _load, child: const Text('Try again')))])
                : _requests.isEmpty
                    ? ListView(children: [const SizedBox(height: 100), const Icon(Icons.inbox_outlined, size: 52), const SizedBox(height: 12), const Center(child: Text('No customer requests yet.'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request = _requests[index];
                          final id = request['id']?.toString() ?? '';
                          final status = request['status']?.toString() ?? 'pending';
                          final expiry = DateTime.tryParse(request['expires_at']?.toString() ?? '');
                          final isPending = status == 'pending' && expiry != null && expiry.isAfter(DateTime.now());
                          final busy = _busyIds.contains(id);
                          final description = request['description']?.toString() ?? '';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Icon(Icons.notification_important_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(request['title']?.toString() ?? 'Customer request', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                                  Chip(label: Text(status.toUpperCase())),
                                ]),
                                const SizedBox(height: 8),
                                Text('Type: ${request['request_type'] ?? 'contact'}'),
                                if (description.isNotEmpty) ...[const SizedBox(height: 6), Text(description)],
                                const SizedBox(height: 8),
                                Text(expiry == null ? 'Response deadline unavailable' : isPending ? 'Respond by ${TimeOfDay.fromDateTime(expiry).format(context)}' : status == 'pending' ? 'Response window ended' : 'Request updated ${DateTime.tryParse(request['updated_at']?.toString() ?? '')?.toLocal() ?? ''}',
                                  style: Theme.of(context).textTheme.bodySmall),
                                if (isPending) ...[
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(child: OutlinedButton(
                                      onPressed: busy ? null : () => _respond(request, 'decline'),
                                      child: const Text('Decline'),
                                    )),
                                    const SizedBox(width: 10),
                                    Expanded(child: FilledButton(
                                      onPressed: busy ? null : () => _respond(request, 'accept'),
                                      child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accept'),
                                    )),
                                  ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
