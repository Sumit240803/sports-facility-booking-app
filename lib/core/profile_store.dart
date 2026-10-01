import 'package:flutter/foundation.dart';

import '../data/zocoplay_api.dart';
import '../data/models.dart';

/// The signed-in user's profile, shared by every screen (role, onboarding).
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._api);
  final ZocoPlayApi _api;

  Profile? profile;
  Object? error;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _api.me();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void set(Profile p) {
    profile = p;
    notifyListeners();
  }

  void clear() {
    profile = null;
    error = null;
    notifyListeners();
  }
}
