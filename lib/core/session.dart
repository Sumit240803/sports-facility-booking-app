import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the auth tokens and persists them across launches.
class Session extends ChangeNotifier {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  String? accessToken;
  String? refreshToken;

  bool get isSignedIn => accessToken != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_accessKey);
    refreshToken = prefs.getString(_refreshKey);
  }

  Future<void> save(String access, String? refresh) async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = access;
    refreshToken = refresh;
    await prefs.setString(_accessKey, access);
    if (refresh != null) await prefs.setString(_refreshKey, refresh);
    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = null;
    refreshToken = null;
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    // Forget the Google account too, so the next sign-in shows the account picker.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
