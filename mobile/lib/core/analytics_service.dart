import 'app_logger.dart';

class AnalyticsService {
  const AnalyticsService();

  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {
    // Backend analytics persistence will be wired to analytics_events
    // after the event contract is implemented. Keep feature code dependent
    // on this abstraction rather than directly coupling to a provider.
    AppLogger.info('analytics=$event properties=$properties');
  }
}

const analyticsService = AnalyticsService();