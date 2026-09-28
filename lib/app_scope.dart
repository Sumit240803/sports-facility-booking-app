import 'package:flutter/widgets.dart';

import 'core/session.dart';
import 'data/easyplay_api.dart';

/// Makes the API and session available to every screen.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.session, required this.api, required super.child});

  final Session session;
  final EasyPlayApi api;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

extension AppScopeX on BuildContext {
  EasyPlayApi get api => AppScope.of(this).api;
  Session get session => AppScope.of(this).session;
}
