import 'package:flutter/widgets.dart';

import 'core/profile_store.dart';
import 'core/push_service.dart';
import 'core/session.dart';
import 'core/theme_controller.dart';
import 'data/easyplay_api.dart';

/// Makes the API, session and profile available to every screen.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.session,
    required this.api,
    required this.profile,
    required this.push,
    required this.theme,
    required super.child,
  });

  final Session session;
  final EasyPlayApi api;
  final ProfileStore profile;
  final PushService push;
  final ThemeController theme;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

extension AppScopeX on BuildContext {
  EasyPlayApi get api => AppScope.of(this).api;
  Session get session => AppScope.of(this).session;
  ProfileStore get profileStore => AppScope.of(this).profile;
  PushService get push => AppScope.of(this).push;
  ThemeController get themeController => AppScope.of(this).theme;
}
