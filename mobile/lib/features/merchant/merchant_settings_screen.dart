import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({required this.businessId, required this.businessName, super.key});
  final String businessId;
  final String businessName;
  @override State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  bool _loading = true, _saving = false, _accepting = false, _rewards = false;
  final _phone = TextEditingController(), _whatsapp = TextEditingController(), _minBill = TextEditingController(), _maxDiscount = TextEditingController();
  String? _error;
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _load() async {
    try {
      final row = await _client.from('businesses').select('phone,whatsapp,accepting_requests,local_rewards_enabled,rewards_min_bill,rewards_max_discount').eq('id', widget.businessId).single();
      _phone.text = row['phone']?.toString() ?? '';
      _whatsapp.text = row['whatsapp']?.toString() ?? '';
      _accepting = row['accepting_requests'] == true;
      _rewards = row['local_rewards_enabled'] == true;
      _minBill.text = row['rewards_min_bill']?.toString() ?? '';
      _maxDiscount.text = row['rewards_max_discount']?.toString() ?? '';
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final minBill = double.tryParse(_minBill.text.trim());
    final maxDiscount = double.tryParse(_maxDiscount.text.trim());
    if (_rewards && (minBill == null || minBill < 0 || maxDiscount == null || maxDiscount < 0)) {
      setState(() => _error = 'Enter valid reward limits or switch Local Rewards off.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await _client.from('businesses').update({
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'accepting_requests': _accepting,
        'local_rewards_enabled': _rewards,
        'rewards_min_bill': _rewards ? minBill : null,
        'rewards_max_discount': _rewards ? maxDiscount : null,
      }).eq('id', widget.businessId);
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business settings saved.'))); }
    } catch (e) { if (mounted) setState(() { _saving = false; _error = e.toString(); }); }
  }

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _phone.dispose(); _whatsapp.dispose(); _minBill.dispose(); _maxDiscount.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.businessName)),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Business Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      SwitchListTile(title: const Text('Accepting Requests'), subtitle: const Text('Turn this off when you do not want new Customer Requests.'), value: _accepting, onChanged: (v) => setState(() => _accepting = v)),
      const Divider(height: 28),
      SwitchListTile(title: const Text('Local Rewards'), subtitle: const Text('Merchant-funded Local Points discounts.'), value: _rewards, onChanged: (v) => setState(() => _rewards = v)),
      if (_rewards) ...[
        const SizedBox(height: 12),
        TextField(controller: _minBill, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum bill', prefixText: '₹ ', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _maxDiscount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maximum discount', prefixText: '₹ ', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        const Text('Default economics: 100 Local Points = ₹10 reward value. The merchant sets the maximum discount.', style: TextStyle(fontSize: 12)),
      ],
      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Colors.red))],
      const SizedBox(height: 20),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save settings')),
    ]),
  );
}