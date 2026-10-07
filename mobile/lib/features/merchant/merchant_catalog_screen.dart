import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCatalogScreen extends StatefulWidget {
  const MerchantCatalogScreen({required this.businessId, required this.businessName, super.key});
  final String businessId;
  final String businessName;
  @override State<MerchantCatalogScreen> createState() => _MerchantCatalogScreenState();
}
class _MerchantCatalogScreenState extends State<MerchantCatalogScreen> {
  final _name = TextEditingController(), _description = TextEditingController(), _price = TextEditingController();
  bool _isService = false, _available = true, _saving = false;
  String? _error;
  SupabaseClient get _client => Supabase.instance.client;
  Future<void> _add() async {
    if (_name.text.trim().length < 2) { setState(() => _error = 'Enter a product/service name.'); return; }
    final price = double.tryParse(_price.text.trim());
    setState(() { _saving = true; _error = null; });
    try {
      final table = _isService ? 'business_services' : 'business_products';
      final data = <String, dynamic>{'business_id': widget.businessId, 'name': _name.text.trim(), 'description': _description.text.trim(), 'price': price, 'is_available': _available, 'status': 'active'};
      if (_isService) data['duration_minutes'] = null;
      await _client.from(table).insert(data);
      _name.clear(); _description.clear(); _price.clear();
      if (mounted) setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added successfully.')));
    } catch (e) { if (mounted) setState(() { _saving = false; _error = e.toString(); }); }
  }
  @override void dispose() { _name.dispose(); _description.dispose(); _price.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.businessName)),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Products & Services', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Add only the items customers actually need to discover. A large catalogue is not required.'),
      const SizedBox(height: 18),
      SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Product'), icon: Icon(Icons.inventory_2_outlined)), ButtonSegment(value: true, label: Text('Service'), icon: Icon(Icons.handyman_outlined))],
        selected: {_isService}, onSelectionChanged: (v) => setState(() => _isService = v.first),
      ),
      const SizedBox(height: 16),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (optional)', prefixText: '₹ ', border: OutlineInputBorder())),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Available'), value: _available, onChanged: (v) => setState(() => _available = v)),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saving ? null : _add, icon: const Icon(Icons.add), label: Text(_saving ? 'Adding…' : 'Add ' + (_isService ? 'service' : 'product'))),
    ]),
  );
}