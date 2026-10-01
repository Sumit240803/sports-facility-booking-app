import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/zocoplay_api.dart';
import '../screens/bookings_screen.dart';
import '../screens/venue_detail_screen.dart';

/// Root navigator + messenger, so push taps and foreground banners work from anywhere.
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Opens the screen a notification points at (from its `data`), if any.
void openNotificationTarget(Map<String, dynamic> data) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final bookingId = data['booking_id'];
  final venueId = data['venue_id'];
  if (bookingId is String && bookingId.isNotEmpty) {
    nav.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: bookingId)));
  } else if (venueId is String && venueId.isNotEmpty) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => VenueDetailScreen(idOrSlug: venueId, title: 'Venue'),
      ),
    );
  }
}

/// Firebase Cloud Messaging: permission, device registration and message handling.
class PushService {
  PushService(this._api);
  final ZocoPlayApi _api;

  static bool _firebaseReady = false;
  String? _token;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Call once before runApp. Push is simply disabled if Firebase isn't configured
  /// for the platform (e.g. iOS without GoogleService-Info.plist).
  static Future<void> initFirebase() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Push disabled: $e');
    }
  }

  /// After sign-in: ask permission, register this device, listen for messages.
  Future<void> start() async {
    if (!_firebaseReady || _subs.isNotEmpty) return;
    final fm = FirebaseMessaging.instance;

    final settings = await fm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _register(await fm.getToken());
    _subs
      ..add(fm.onTokenRefresh.listen(_register))
      ..add(FirebaseMessaging.onMessage.listen(_showInApp))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => openNotificationTarget(m.data)));

    // App was launched by tapping a notification.
    final initial = await fm.getInitialMessage();
    if (initial != null) openNotificationTarget(initial.data);
  }

  /// Before sign-out (while still authenticated): stop pushes to this device.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _api.unregisterPushToken(token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best effort: the backend also drops dead tokens on send.
    }
  }

  Future<void> _register(String? token) async {
    if (token == null || token == _token) return;
    try {
      await _api.registerPushToken(token, 'android');
      _token = token;
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  /// FCM doesn't show a system notification while the app is open, so show a banner.
  void _showInApp(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.title != null) Text(n.title!, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (n.body != null) Text(n.body!),
          ],
        ),
        action: m.data.containsKey('booking_id') || m.data.containsKey('venue_id')
            ? SnackBarAction(label: 'View', onPressed: () => openNotificationTarget(m.data))
            : null,
      ),
    );
  }
}
