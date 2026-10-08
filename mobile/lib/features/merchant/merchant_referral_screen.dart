import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';

class MerchantReferralScreen extends StatefulWidget {
  const MerchantReferralScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<MerchantReferralScreen> createState() => _MerchantReferralScreenState();
}

class _MerchantReferralScreenState extends State<MerchantReferralScreen> {
  bool _loading = true;
  String? _token;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  String get _publicWebUrl => AppConfig.publicWebUrl.trim().replaceFirst(RegExp(r'/$'), '');

  String get _referralUrl => '$_publicWebUrl/r/$_token';

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    if (_publicWebUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Public web URL is not configured for referral QR.';
          _loading = false;
        });
      }
      return;
    }

    try {
      final row = await _client
          .from('merchant_referral_tokens')
          .select('token,is_active')
          .eq('business_id', widget.businessId)
          .maybeSingle();

      if (!mounted) return;
      if (row == null || row['is_active'] != true) {
        setState(() {
          _error = 'Referral QR is not active for this business yet.';
          _loading = false;
        });
        return;
      }

      final token = row['token']?.toString().trim();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Referral QR token is missing.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _token = token;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load the referral QR.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyLink() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _referralUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral link copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Customers')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.businessName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show this QR at your counter or share the link. '
            'You earn 10 Marketing Credits only when the referred customer '
            'completes the backend validation flow.',
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_error!),
                trailing: IconButton(
                  onPressed: _loadToken,
                  icon: const Icon(Icons.refresh),
                  ),
              ),
            )
          else if (_token != null) ...[
            Center(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: QrImageView(
                    data: _referralUrl,
                    version: QrVersions.auto,
                    size: 260,
                    gapless: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('10 Marketing Credits'),
                subtitle: Text(
                  'Earned after a referred customer becomes qualified. '
                  'Install-only referrals do not earn credits.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              _referralUrl,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy),
              label: const Text('Copy Referral Link'),
            ),
          ],
        ],
      ),
    );
  }
}
