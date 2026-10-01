import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_scope.dart';
import 'core/api_client.dart';
import './widgets/app_icons.dart';

/// Native Google Sign-In.
///
/// The OS account picker returns a Google ID token (requested for the backend's web client id,
/// with a hashed nonce); the backend has Supabase verify it and returns our session. No browser,
/// cookies or deep-link redirects are involved.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  static String _randomNonce() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.api;
    final session = context.session;
    try {
      final webClientId = await api.googleWebClientId();

      // Google puts sha256(nonce) in the token; Supabase checks it against the raw nonce we send.
      final rawNonce = _randomNonce();
      final google = GoogleSignIn.instance;
      await google.initialize(serverClientId: webClientId, nonce: sha256.convert(utf8.encode(rawNonce)).toString());

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw 'Google did not return an ID token. Please try again.';

      final (access, refresh) = await api.signInWithGoogleIdToken(idToken, rawNonce);
      await session.save(access, refresh);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return; // user closed the picker
      _fail(switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not set up for this app build (check the Android OAuth client and SHA-1).',
        GoogleSignInExceptionCode.uiUnavailable => 'Couldn\'t open the Google account picker.',
        _ => 'Google sign-in failed: ${e.description ?? e.code.name}',
      });
    } on ApiException catch (e) {
      _fail(e.statusCode == 503 ? 'Google sign-in is not configured on the server yet.' : e.message);
    } catch (e) {
      _fail('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
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
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        AppIcon(AppIcons.error, color: scheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const AppIcon(AppIcons.google),
                  label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
                ),
                const SizedBox(height: 12),
                Text(
                  'The first sign-in can take up to a minute while the server wakes up.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
