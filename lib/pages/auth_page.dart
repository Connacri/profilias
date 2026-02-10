
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../strings.dart';
import '../widgets/auth_error_message.dart';
import 'recover_password_page.dart';

enum AuthMode { signIn, signUp }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _lastHelpUrl;
  bool _awaitingEmailVerification = false;
  AuthMode _mode = AuthMode.signIn;
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _lastHelpUrl = null;
      _awaitingEmailVerification = false;
    });
  }

  void _showError(String message, {bool includeHelp = false}) {
    if (!mounted) {
      return;
    }
    final helpText = includeHelp
        ? 'Voir la doc: ${AppConfig.supabaseGoogleHelpUrl}'
        : '';
    setState(
      () => _error = includeHelp && helpText.isNotEmpty
          ? '$message\n$helpText'
          : message,
    );
    if (includeHelp && helpText.isNotEmpty) {
      _lastHelpUrl = AppConfig.supabaseGoogleHelpUrl;
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

  String? _validatePassword(String value) {
    final hasMinLength = value.length >= 8;
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    if (hasMinLength && hasUpper && hasLower && hasDigit) {
      return null;
    }
    return Strings.passwordRequirements;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  Future<void> _copyGoogleConfig() async {
    final payload = [
      'GOOGLE_WEB_CLIENT_ID=${_authService.webClientId}',
      'GOOGLE_IOS_CLIENT_ID=${_authService.iosClientId}',
      'SUPABASE_REDIRECT_URL=${AppConfig.supabaseRedirectUrl}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: payload));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.configCopied)),
    );
  }

  bool _isLikelyUserNotFound(AuthException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('invalid login credentials') ||
        msg.contains('user not found') ||
        msg.contains('not found');
  }

  bool _isUserAlreadyExists(AuthException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('user already');
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastHelpUrl = null;
    });

    try {
      await _authService.signInWithGoogle();
    } on AuthException catch (e) {
      _showError(e.message, includeHelp: true);
    } on StateError catch (e) {
      _showError(e.message, includeHelp: true);
    } catch (_) {
      _showError(Strings.googleError, includeHelp: true);
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
      await _authService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      if (_isLikelyUserNotFound(e)) {
        _setMode(AuthMode.signUp);
        _showError(Strings.invalidCredentials);
      } else {
        _showError(e.message);
      }
    } catch (_) {
      _showError(Strings.connectionError);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    final validation = _validatePassword(_passwordController.text);
    if (validation != null) {
      _showError(validation);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _lastHelpUrl = null;
    });
    try {
      final response = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (response.session == null) {
        setState(() => _awaitingEmailVerification = true);
      }
    } on AuthException catch (e) {
      if (_isUserAlreadyExists(e)) {
        _setMode(AuthMode.signIn);
        _showError(Strings.invalidCredentials);
      } else {
        _showError(e.message);
      }
    } catch (_) {
      _showError(Strings.signUpError);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendSecondsLeft > 0) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.resendSignupEmail(_emailController.text.trim());
      _startResendCooldown();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(Strings.connectionError);
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
      _showError(Strings.openDocsError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showGoogle = !_isWindowsDesktop;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.signInTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<AuthMode>(
              segments: const [
                ButtonSegment(
                  value: AuthMode.signIn,
                  label: Text(Strings.signIn),
                ),
                ButtonSegment(
                  value: AuthMode.signUp,
                  label: Text(Strings.signUp),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => _setMode(value.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: Strings.emailLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: Strings.passwordLabel),
            ),
            const SizedBox(height: 8),
            if (_mode == AuthMode.signUp)
              Text(
                Strings.passwordRequirements,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AuthErrorMessage(_error!),
              ),
            if (_awaitingEmailVerification && _mode == AuthMode.signUp)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Text(
                      Strings.awaitingEmailTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Strings.awaitingEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Strings.awaitingEmailHint,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: const Text(Strings.trySignIn),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _resendVerificationEmail,
                      child: Text(
                        _resendSecondsLeft > 0
                            ? '${Strings.resendEmailIn} ${_resendSecondsLeft}s'
                            : Strings.resendEmail,
                      ),
                    ),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_mode == AuthMode.signIn ? _signIn : _signUp),
              child: Text(
                _mode == AuthMode.signIn ? Strings.signIn : Strings.signUp,
              ),
            ),
            const SizedBox(height: 12),
            if (_mode == AuthMode.signIn)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecoverPasswordPage()),
                ),
                child: const Text(Strings.forgotPassword),
              ),
            if (showGoogle)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text(Strings.continueWithGoogle),
              ),
            if (_lastHelpUrl != null)
              TextButton(
                onPressed: _openHelpUrl,
                child: const Text(Strings.openDocs),
              ),
            const SizedBox(height: 8),
            if (_authService.hasAnyGoogleClientId)
              TextButton(
                onPressed: _copyGoogleConfig,
                child: const Text(Strings.copyGoogleConfig),
              ),
          ],
        ),
      ),
    );
  }
}
