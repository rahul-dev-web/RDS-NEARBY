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
  String? _token;
  int _points = 0;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  String get _publicWebUrl => AppConfig.publicWebUrl.trim().replaceFirst(RegExp(r'/$'), '');
  String get _referralUrl => '$_publicWebUrl/r/$_token';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_publicWebUrl.isEmpty) {
      if (mounted) setState(() { _error = 'Public web URL is not configured for referral links.'; _loading = false; });
      return;
    }

    try {
      final result = await _client.functions.invoke('create-customer-referral');
      final data = Map<String, dynamic>.from(result.data as Map);
      final token = data['token']?.toString().trim();
      if (token == null || token.isEmpty) throw Exception('Referral token unavailable');

      final wallet = await _client
          .from('customer_wallets')
          .select('balance')
          .eq('user_id', _client.auth.currentUser!.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _token = token;
        _points = (wallet?['balance'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your referral and Local Points.'; _loading = false; });
    }
  }

  Future<void> _copy() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _referralUrl));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Points & Referral')),
      body: ListView(
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
          const SizedBox(height: 16),
          const Text('Invite a friend', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Your friend must verify, complete onboarding and perform meaningful activity within 48 hours. Then you earn 10 Local Points.'),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_error!), trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh))))
          else if (_token != null) ...[
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
    );
  }
}
