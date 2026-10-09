import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';

class MerchantOnboardingScreen extends StatefulWidget {
  const MerchantOnboardingScreen({super.key});

  @override
  State<MerchantOnboardingScreen> createState() => _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();
  final _locality = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;
  AuthService get _auth => AuthService(_client);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _client.from('categories')
          .select('id,name,slug,icon')
          .eq('status', 'active')
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = rows.map((row) => Map<String, dynamic>.from(row)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load categories: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setState(() => _error = 'Enter valid latitude and longitude.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final business = await _auth.createBusiness(
        name: _name.text,
        categoryId: _categoryId!,
        lat: lat,
        lng: lng,
        description: _description.text,
        phone: _phone.text,
        whatsapp: _whatsapp.text,
        address: _address.text,
        localityId: _locality.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(business);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _locality.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your shop')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Business profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Start with the information customers need to find and contact you.'),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Business name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your business name' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categories.map((category) => DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(category['name'].toString()),
                    )).toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                    validator: (v) => v == null ? 'Select a category' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Short description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _whatsapp,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'WhatsApp', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _locality,
                    decoration: const InputDecoration(labelText: 'Locality / area', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                        validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Required' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _lng,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                        validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Required' : null,
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Location is mandatory. GPS picker will be added through the location-provider layer; for this foundation, enter coordinates manually.'),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _saving ? null : _createBusiness,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_saving ? 'Creating…' : 'Create business'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
