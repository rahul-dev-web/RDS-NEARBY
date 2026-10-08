import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralDeepLinkService {
  ReferralDeepLinkService._();

  static final ReferralDeepLinkService instance = ReferralDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _pendingToken;
  bool _initialized = false;
  String? _lastSubmittedToken;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _capture(initial);
    } catch (_) {}

    _subscription = _appLinks.uriLinkStream.listen(_capture);
  }

  void _capture(Uri uri) {
    final token = _extractToken(uri);
    if (token != null) _pendingToken = token;
  }

  String? _extractToken(Uri uri) {
    final segments = uri.pathSegments;
    final index = segments.indexOf('r');
    if (index < 0 || index + 1 >= segments.length) return null;

    final token = segments[index + 1].trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(token)) return null;
    return token;
  }

  Future<void> submitPendingReferral() async {
    final token = _pendingToken;
    if (token == null || token == _lastSubmittedToken) return;

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    try {
      final response = await client.functions.invoke(
        'create-referral',
        body: {'token': token},
      );

      if (response.status >= 200 && response.status < 300) {
        _lastSubmittedToken = token;
        _pendingToken = null;
      }
    } catch (_) {
      // Referral attribution must never block signup or app usage.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
