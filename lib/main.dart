import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/api_client.dart';
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

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: session,
      api: EasyPlayApi(ApiClient(session)),
      child: MaterialApp(
        title: 'EasyPlay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => session.isSignedIn ? const HomeShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
