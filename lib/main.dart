import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/api_client.dart';
import 'core/profile_store.dart';
import 'core/session.dart';
import 'data/easyplay_api.dart';
import 'login.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.load();
  runApp(MainApp(session: session));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.session});
  final Session session;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final api = EasyPlayApi(ApiClient(widget.session));
  late final profile = ProfileStore(api);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return AppScope(
      session: session,
      api: api,
      profile: profile,
      child: MaterialApp(
        title: 'EasyPlay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: ListenableBuilder(
          listenable: session,
          // Keyed by token presence so a new sign-in gets a fresh shell (and profile load).
          builder: (context, _) => session.isSignedIn ? const HomeShell(key: ValueKey('shell')) : const LoginScreen(),
        ),
      ),
    );
  }
}
