
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../strings.dart';
import '../widgets/auth_error_message.dart';
import 'email_verification_page.dart';
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
  AuthMode _mode = AuthMode.signIn;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _lastHelpUrl = null;
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

  _PasswordStrength _passwordStrength(String value) {
    var score = 0;
    if (value.length >= 8) score += 1;
    if (value.contains(RegExp(r'[A-Z]'))) score += 1;
    if (value.contains(RegExp(r'[a-z]'))) score += 1;
    if (value.contains(RegExp(r'\d'))) score += 1;
    if (score <= 1) {
      return const _PasswordStrength(0.33, Strings.passwordStrengthWeak);
    }
    if (score == 2 || score == 3) {
      return const _PasswordStrength(0.66, Strings.passwordStrengthMedium);
    }
    return const _PasswordStrength(1.0, Strings.passwordStrengthStrong);
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
        if (!mounted) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: _emailController.text.trim(),
            ),
          ),
        );
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
    final strength = _passwordStrength(_passwordController.text);

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
              Column(
                children: [
                  Text(
                    Strings.passwordRequirements,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: strength.progress),
                  const SizedBox(height: 4),
                  Text(
                    strength.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _PasswordChecklist(password: _passwordController.text),
                ],
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AuthErrorMessage(_error!),
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

class _PasswordStrength {
  const _PasswordStrength(this.progress, this.label);

  final double progress;
  final String label;
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.password});

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasUpper => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => password.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => password.contains(RegExp(r'\d'));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChecklistRow(label: '8+ caractères', ok: _hasMinLength),
        _ChecklistRow(label: '1 majuscule', ok: _hasUpper),
        _ChecklistRow(label: '1 minuscule', ok: _hasLower),
        _ChecklistRow(label: '1 chiffre', ok: _hasDigit),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
