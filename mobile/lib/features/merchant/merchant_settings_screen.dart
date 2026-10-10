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
  final Map<String, TimeOfDay?> _open = {}, _close = {};
  final List<MapEntry<String, String>> _days = const [MapEntry('mon', 'Monday'), MapEntry('tue', 'Tuesday'), MapEntry('wed', 'Wednesday'), MapEntry('thu', 'Thursday'), MapEntry('fri', 'Friday'), MapEntry('sat', 'Saturday'), MapEntry('sun', 'Sunday')];
  final Set<String> _closedDays = {};
  final _phone = TextEditingController(), _whatsapp = TextEditingController(), _minBill = TextEditingController(), _maxDiscount = TextEditingController();
  String? _error;
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _load() async {
    try {
      final row = await _client.from('businesses').select('phone,whatsapp,accepting_requests,local_rewards_enabled,rewards_min_bill,rewards_max_discount,opening_hours').eq('id', widget.businessId).single();
      _phone.text = row['phone']?.toString() ?? '';
      _whatsapp.text = row['whatsapp']?.toString() ?? '';
      _accepting = row['accepting_requests'] == true;
      _rewards = row['local_rewards_enabled'] == true;
      _minBill.text = row['rewards_min_bill']?.toString() ?? '';
      _maxDiscount.text = row['rewards_max_discount']?.toString() ?? '';
      final hours = Map<String, dynamic>.from(row['opening_hours'] is Map ? row['opening_hours'] as Map : {});
      for (final day in _days) {
        final value = Map<String, dynamic>.from(hours[day.key] is Map ? hours[day.key] as Map : {});
        _open[day.key] = _parseTime(value['open']?.toString()) ?? const TimeOfDay(hour: 9, minute: 0);
        _close[day.key] = _parseTime(value['close']?.toString()) ?? const TimeOfDay(hour: 18, minute: 0);
        if (value['closed'] == true) _closedDays.add(day.key);
      }
    } catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String day, bool opening) async {
    final initial = opening ? (_open[day] ?? const TimeOfDay(hour: 9, minute: 0)) : (_close[day] ?? const TimeOfDay(hour: 18, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() { (opening ? _open : _close)[day] = picked; });
  }

  Future<void> _save() async {
    final minBill = double.tryParse(_minBill.text.trim());
    final maxDiscount = double.tryParse(_maxDiscount.text.trim());
    if (_rewards && (minBill == null || !minBill.isFinite || minBill <= 0 || maxDiscount == null || !maxDiscount.isFinite || maxDiscount <= 0)) {
      setState(() => _error = 'Local Rewards needs a minimum bill and maximum discount, both greater than ₹0. Or switch Local Rewards off.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final openingHours = <String, dynamic>{};
      for (final day in _days) {
        openingHours[day.key] = {
          'open': _formatTime(_open[day.key] ?? const TimeOfDay(hour: 9, minute: 0)),
          'close': _formatTime(_close[day.key] ?? const TimeOfDay(hour: 18, minute: 0)),
          'closed': _closedDays.contains(day.key),
        };
      }
      await _client.from('businesses').update({
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'accepting_requests': _accepting,
        'local_rewards_enabled': _rewards,
        'rewards_min_bill': _rewards ? minBill : null,
        'rewards_max_discount': _rewards ? maxDiscount : null,
        'opening_hours': openingHours,
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
      const Text('Business Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Set the weekly hours used for the shop Open/Closed status.'),
      const SizedBox(height: 10),
      ..._days.map((day) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        SizedBox(width: 78, child: Text(day.value, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: TextButton(onPressed: _closedDays.contains(day.key) ? null : () => _pickTime(day.key, true), child: Text(_formatTime(_open[day.key] ?? const TimeOfDay(hour: 9, minute: 0))))),
        Expanded(child: TextButton(onPressed: _closedDays.contains(day.key) ? null : () => _pickTime(day.key, false), child: Text(_formatTime(_close[day.key] ?? const TimeOfDay(hour: 18, minute: 0))))),
        Checkbox(value: _closedDays.contains(day.key), onChanged: (v) => setState(() { if (v == true) { _closedDays.add(day.key); } else { _closedDays.remove(day.key); } })),
      ])))),
      const SizedBox(height: 8),
      const Text('Tick Closed for a weekly holiday.', style: TextStyle(fontSize: 12)),
      const Divider(height: 28),
      SwitchListTile(title: const Text('Local Rewards'), subtitle: const Text('Merchant-funded Local Points discounts.'), value: _rewards, onChanged: (v) => setState(() => _rewards = v)),
      if (_rewards) ...[
        const SizedBox(height: 12),
        TextField(controller: _minBill, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum bill', prefixText: '₹ ', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _maxDiscount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maximum discount', prefixText: '₹ ', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        const Text('Default economics: 100 Local Points = ₹10 reward value. Minimum bill and maximum discount must both be greater than ₹0.', style: TextStyle(fontSize: 12)),
      ],
      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Colors.red))],
      const SizedBox(height: 20),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save settings')),
    ]),
  );
}
