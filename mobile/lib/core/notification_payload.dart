/// Validates the untrusted request identifier supplied by an FCM payload.
///
/// Notification data is external input. Only a UUID-shaped request ID may be
/// used to begin authenticated, server-authorized deep-link resolution.
class NotificationPayload {
  NotificationPayload._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static String? requestIdFrom(Map<String, dynamic> data) {
    final value = data['requestId'];
    if (value is! String || !_uuidPattern.hasMatch(value)) return null;
    return value;
  }
}
