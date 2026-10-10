import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort product telemetry. Analytics failures must never block a
/// customer or merchant from completing the primary action.
///
/// The optional client preserves the existing `AnalyticsService()` call
/// shape while allowing features to pass their already-initialized client.
class AnalyticsService {
  const AnalyticsService([this._client]);

  final SupabaseClient? _client;

  Future<void> record(
    String eventName, {
    String? businessId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final properties = <String, Object?>{...metadata};
    if (businessId != null) properties['business_id'] = businessId;
    await track(eventName, properties: properties);
  }

  Future<void> track(
    String event, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    try {
      final client = _client ?? Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final metadata = <String, dynamic>{...properties};
      final businessId = metadata.remove('business_id')?.toString();

      await client.rpc('record_analytics_event', params: {
        'p_event_name': event,
        'p_business_id': businessId,
        'p_metadata': metadata,
      });
    } catch (_) {
      // Product analytics is intentionally non-blocking.
    }
  }
}

const analyticsService = AnalyticsService();
