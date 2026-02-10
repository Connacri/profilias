import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _supabaseRedirectScheme = 'com.profilias.oran.profilias';
const _supabaseRedirectHost = 'login-callback';
const _supabaseRedirectUrl =
    '$_supabaseRedirectScheme://$_supabaseRedirectHost/';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _lastHelpUrl;

  bool _isPlaceholderClientId(String value) {
    return value.isEmpty ||
        value.contains('YOUR_WEB_CLIENT_ID') ||
        value.contains('YOUR_IOS_CLIENT_ID');
  }

  void _showError(String message, {bool includeHelp = false}) {
    if (!mounted) {
      return;
    }
    final helpText = includeHelp
        ? 'Voir la doc: https://supabase.com/docs/guides/auth/social-login/auth-google'
        : '';
    setState(
      () => _error = includeHelp && helpText.isNotEmpty
          ? '$message\n$helpText'
          : message,
    );
    if (includeHelp && helpText.isNotEmpty) {
      _lastHelpUrl =
          'https://supabase.com/docs/guides/auth/social-login/auth-google';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          includeHelp && helpText.isNotEmpty ? '$message $helpText' : message,
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _copyGoogleConfig() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';
    final payload = [
      'GOOGLE_WEB_CLIENT_ID=$webClientId',
      'GOOGLE_IOS_CLIENT_ID=$iosClientId',
      'SUPABASE_REDIRECT_URL=$_supabaseRedirectUrl',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: payload));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Config copiée dans le presse-papiers.')),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastHelpUrl = null;
    });

    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
        );
        return;
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
          final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

          if (_isPlaceholderClientId(webClientId)) {
            throw StateError(
              'GOOGLE_WEB_CLIENT_ID invalide dans .env (placeholder ou vide).',
            );
          }
          if (defaultTargetPlatform == TargetPlatform.iOS &&
              _isPlaceholderClientId(iosClientId)) {
            throw StateError(
              'GOOGLE_IOS_CLIENT_ID invalide dans .env (placeholder ou vide).',
            );
          }

          final googleSignIn = GoogleSignIn.instance;
          await googleSignIn.initialize(
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? iosClientId
                : null,
            serverClientId: webClientId,
          );

          final googleUser = await googleSignIn.authenticate();
          final googleAuthorization =
              await googleUser.authorizationClient.authorizationForScopes([]);
          final googleAuthentication = googleUser.authentication;
          final idToken = googleAuthentication.idToken;
          final accessToken = googleAuthorization?.accessToken;

          if (idToken == null) {
            throw StateError('Token Google manquant.');
          }

          await Supabase.instance.client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          return;
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
          await Supabase.instance.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: _supabaseRedirectUrl,
          );
          return;
        case TargetPlatform.fuchsia:
          throw StateError('Plateforme non supportée.');
      }
    } on AuthException catch (e) {
      _showError(e.message, includeHelp: true);
    } on StateError catch (e) {
      _showError(e.message, includeHelp: true);
    } catch (_) {
      _showError('Erreur Google Sign-In.', includeHelp: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastHelpUrl = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erreur de connexion.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastHelpUrl = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erreur lors de la création du compte.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openHelpUrl() async {
    final url = _lastHelpUrl;
    if (url == null) {
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Impossible d’ouvrir la documentation.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: const Text('Se connecter'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: const Text('Créer un compte'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Continuer avec Google'),
            ),
            if (_lastHelpUrl != null)
              TextButton(
                onPressed: _openHelpUrl,
                child: const Text('Ouvrir la documentation'),
              ),
            const SizedBox(height: 8),
            if ((dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').isNotEmpty ||
                (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').isNotEmpty)
              TextButton(
                onPressed: _copyGoogleConfig,
                child: const Text('Copier la config Google'),
              ),
          ],
        ),
      ),
    );
  }
}
