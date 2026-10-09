import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/merchant/merchant_requests_screen.dart';
import 'notification_payload.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _currentToken;
  String? _pendingRequestId;
  bool _initialized = false;
  bool _firebaseReady = false;

  static const _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  Future<void> initialize(SupabaseClient client) async {
    if (_initialized) return;
    _initialized = true;
    _client = client;

    // Firebase is optional until platform configuration is added with FlutterFire CLI.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } on FirebaseException catch (error) {
      debugPrint('FCM disabled: Firebase is not configured (${error.code}).');
      return;
    } catch (error) {
      debugPrint('FCM disabled: Firebase initialization failed ($error).');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('FCM permission setup was not completed: $error');
    }

    _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _tokenSubscription = messaging.onTokenRefresh.listen((token) {
      final previousToken = _currentToken;
      _currentToken = token;
      unawaited(() async {
        if (previousToken != null && previousToken != token) {
          await _unregisterToken(previousToken);
        }
        await _registerToken(token);
      }());
    });

    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleMessageTap(initialMessage);
    } catch (error) {
      debugPrint('FCM initial notification could not be read: $error');
    }

    _authSubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(_registerCurrentToken());
        unawaited(flushPendingNavigation());
      }
    });

    if (client.auth.currentUser != null) {
      await _registerCurrentToken();
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!_firebaseReady || _client?.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = token;
      await _registerToken(token);
    } catch (error) {
      debugPrint('FCM token registration could not complete: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    final client = _client;
    if (!_firebaseReady || client == null || client.auth.currentUser == null) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': platform,
        'p_app_version': _appVersion,
      });
    } catch (error) {
      debugPrint('FCM device token could not be saved: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_firebaseReady || _client?.auth.currentUser == null) return;
    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _unregisterToken(token);
      _currentToken = null;
    } catch (error) {
      debugPrint('FCM device token could not be deactivated: $error');
    }
  }

  Future<void> _unregisterToken(String token) async {
    final client = _client;
    if (!_firebaseReady || client == null || client.auth.currentUser == null) return;
    await client.rpc('unregister_device_token', params: {'p_token': token});
  }

  void _handleMessageTap(RemoteMessage message) {
    final requestId = NotificationPayload.requestIdFrom(message.data);
    if (requestId == null) return;
    _pendingRequestId = requestId;
    unawaited(flushPendingNavigation());
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final requestId = NotificationPayload.requestIdFrom(message.data);
    if (requestId == null) return;
    final context = navigatorKey.currentContext;
    if (context == null) {
      _pendingRequestId = requestId;
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message.notification?.title ?? 'New Customer Request'),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () {
            _pendingRequestId = requestId;
            unawaited(flushPendingNavigation());
          },
        ),
      ),
    );
  }

  Future<void> flushPendingNavigation() async {
    final requestId = _pendingRequestId;
    final client = _client;
    final navigator = navigatorKey.currentState;
    if (requestId == null || client == null || navigator == null) return;
    if (client.auth.currentUser == null) return;

    _pendingRequestId = null;
    try {
      final request = await client
          .from('customer_requests')
          .select('business_id')
          .eq('id', requestId)
          .maybeSingle();
      final businessId = request?['business_id']?.toString();
      if (businessId == null) {
        debugPrint('Notification request is not available to the current account.');
        return;
      }

      final business = await client
          .from('businesses')
          .select('name')
          .eq('id', businessId)
          .maybeSingle();
      final businessName = business?['name']?.toString() ?? 'Your business';

      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MerchantRequestsScreen(
            businessId: businessId,
            businessName: businessName,
            initialRequestId: requestId,
          ),
        ),
      );
    } catch (error) {
      _pendingRequestId = requestId;
      debugPrint('Could not open the Customer Request from notification: $error');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    _tapSubscription?.cancel();
    _foregroundSubscription?.cancel();
  }
}
