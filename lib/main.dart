import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/api_client.dart';
import 'core/profile_store.dart';
import 'core/push_service.dart';
import 'core/session.dart';
import 'core/theme_controller.dart';
import 'data/zocoplay_api.dart';
import 'login.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.load();
  final theme = ThemeController();
  await theme.load();
  await PushService.initFirebase();
  runApp(MainApp(session: session, theme: theme));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.session, required this.theme});
  final Session session;
  final ThemeController theme;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final api = ZocoPlayApi(ApiClient(widget.session));
  late final profile = ProfileStore(api);
  late final push = PushService(api);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return AppScope(
      session: session,
      api: api,
      profile: profile,
      push: push,
      theme: widget.theme,
      child: ListenableBuilder(
        listenable: widget.theme,
        builder: (context, _) => MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          title: 'ZocoPlay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.theme.mode,
          home: ListenableBuilder(
            listenable: session,
            // Keyed by token presence so a new sign-in gets a fresh shell (and profile load).
            builder: (context, _) => session.isSignedIn ? const HomeShell(key: ValueKey('shell')) : const LoginScreen(),
          ),
        ),
      ),
    );
  }
}
