import 'package:flutter_test/flutter_test.dart';
import 'package:rds_nearby/core/notification_payload.dart';

void main() {
  group('NotificationPayload.requestIdFrom', () {
    test('accepts a valid UUID request identifier', () {
      expect(
        NotificationPayload.requestIdFrom({
          'requestId': '550e8400-e29b-41d4-a716-446655440000',
        }),
        '550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('rejects a missing request identifier', () {
      expect(NotificationPayload.requestIdFrom({}), isNull);
    });

    test('rejects a non-string request identifier', () {
      expect(NotificationPayload.requestIdFrom({'requestId': 123}), isNull);
    });

    test('rejects arbitrary strings and path injection', () {
      expect(NotificationPayload.requestIdFrom({'requestId': '../admin'}), isNull);
      expect(
        NotificationPayload.requestIdFrom({
          'requestId': '550e8400-e29b-41d4-a716-446655440000/../../admin',
        }),
        isNull,
      );
    });
  });
}
