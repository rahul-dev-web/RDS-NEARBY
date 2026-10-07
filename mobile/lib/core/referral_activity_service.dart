import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralActivityService {
  const ReferralActivityService(this._client);

  final SupabaseClient _client;

  Future<void> recordMeaningfulActivity(String eventType) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final referral = await _client
        .from('referrals')
        .select('id,status')
        .eq('referred_user_id', user.id)
        .eq('status', 'PENDING')
        .maybeSingle();

    if (referral == null) return;

    try {
      await _client.functions.invoke(
        'record-referral-activity',
        body: {
          'referral_id': referral['id'],
          'event_type': eventType,
        },
      );
    } catch (_) {
      // Referral qualification must never block the customer's primary action.
    }
  }
}
