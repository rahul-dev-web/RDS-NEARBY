import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this.client);
  final SupabaseClient client;

  Future<void> sendPhoneOtp(String phone) async {
    await client.auth.signInWithOtp(phone: normalizeIndianPhone(phone));
  }

  Future<void> verifyPhoneOtp({required String phone, required String token}) async {
    await client.auth.verifyOTP(
      type: OtpType.sms,
      token: token.trim(),
      phone: normalizeIndianPhone(phone),
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return client.from('profiles').select('id, role, name, phone, status').eq('id', userId).maybeSingle();
  }

  Future<void> completeProfile({required String name}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');
    await client.from('profiles').update({'name': name.trim()}).eq('id', userId);
  }

  Future<String> setInitialRole(String role) async {
    final response = await client.functions.invoke('set-initial-role', body: {'role': role});
    if (response.status < 200 || response.status >= 300) {
      final message = response.data is Map && response.data['error'] != null
          ? response.data['error'].toString()
          : 'Unable to set role';
      throw FunctionsException(message, status: response.status);
    }
    final data = response.data;
    if (data is! Map || data['role'] is! String) {
      throw const FunctionsException('Invalid role response');
    }
    return data['role'] as String;
  }

  Future<void> signOut() => client.auth.signOut();

  static String normalizeIndianPhone(String input) {
    final raw = input.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.startsWith('+91')) return raw;
    if (raw.startsWith('91') && raw.length == 12) return '+$raw';
    if (RegExp(r'^\d{10}$').hasMatch(raw)) return '+91$raw';
    throw const AuthException('Enter a valid 10-digit Indian mobile number');
  }
}
