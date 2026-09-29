import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'app_scope.dart';

/// Google sign-in via the backend's OAuth flow.
///
/// The backend redirects to `FRONTEND_URL/auth/callback#access_token=...`, so
/// set `FRONTEND_URL=easyplay://app` in the backend `.env` for the app to
/// receive the tokens.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: context.api.googleSignInUrl,
        callbackUrlScheme: 'easyplay',
      );
      final params = Uri.splitQueryString(Uri.parse(result).fragment);
      if (params['error'] != null) throw Exception(params['error']);
      final access = params['access_token'];
      if (access == null) throw Exception('No access token returned');
      if (!mounted) return;
      await context.session.save(access, params['refresh_token']);
    } catch (e) {
      _showError('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dev helper: paste an access token copied from Swagger / the web app.
  Future<void> _pasteToken() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use access token'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Paste a bearer token'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    if (token == null || token.isEmpty || !mounted) return;
    await context.session.save(token, null);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/icon/icon.png', width: 104, height: 104),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'EasyPlay',
                  textAlign: TextAlign.center,
                  style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find and book courts near you in seconds.',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : _pasteToken, child: const Text('Developer: use access token')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
