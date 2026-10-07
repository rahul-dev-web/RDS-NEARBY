import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>?> getProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  Future<void> completeProfile({required String name}) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await client.from('profiles').update({'name': name.trim()}).eq('id', user.id);
  }

  Future<void> sendOtp(String phone) async {
    await client.auth.signInWithOtp(phone: phone);
  }

  Future<void> sendPhoneOtp(String phone) => sendOtp(phone);

  Future<void> verifyOtp(String phone, String token) async {
    await client.auth.verifyOTP(type: OtpType.sms, phone: phone, token: token);
  }

  Future<void> verifyPhoneOtp({required String phone, required String token}) =>
      verifyOtp(phone, token);

  Future<String> setInitialRole(String role) async {
    final response = await client.functions.invoke('set-initial-role', body: {'role': role});
    final data = response.data;
    if (data is! Map) throw const FormatException('Invalid role response');
    return data['role']?.toString() ?? (throw const FormatException('Role missing'));
  }

  Future<Map<String, dynamic>> createBusiness({
    required String name,
    required String categoryId,
    required double lat,
    required double lng,
    String description = '',
    String phone = '',
    String whatsapp = '',
    String address = '',
    String localityId = '',
    Map<String, dynamic>? openingHours,
  }) async {
    final response = await client.functions.invoke('create-business', body: {
      'name': name,
      'category_id': categoryId,
      'lat': lat,
      'lng': lng,
      'description': description,
      'phone': phone,
      'whatsapp': whatsapp,
      'address': address,
      'locality_id': localityId,
      'opening_hours': openingHours ?? _defaultOpeningHours,
    });
    final data = response.data;
    if (data is! Map || data['business'] is! Map) {
      final error = data is Map ? data['error'] : 'invalid response';
      throw FormatException('Business creation failed: $error');
    }
    return Map<String, dynamic>.from(data['business'] as Map);
  }

  Future<List<Map<String, dynamic>>> getMyBusinesses() async {
    final rows = await client.from('businesses')
        .select('id,name,slug,status,verification_status,category_id,lat,lng')
        .eq('owner_id', client.auth.currentUser!.id)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static const Map<String, dynamic> _defaultOpeningHours = {
    'monday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'tuesday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'wednesday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'thursday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'friday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'saturday': {'open': '09:00', 'close': '21:00', 'closed': false},
    'sunday': {'open': '09:00', 'close': '21:00', 'closed': false},
  };
}
