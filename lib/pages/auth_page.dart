
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
    return msg.contains('user not found');
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
      final exists =
          await _authService.safeEmailExists(_emailController.text.trim());
      if (!exists) {
        _setMode(AuthMode.signUp);
        _showError(Strings.switchToSignUp);
        return;
      }
      await _authService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (_isLikelyUserNotFound(e)) {
        _setMode(AuthMode.signUp);
        _showError(Strings.switchToSignUp);
      } else if (msg.contains('invalid login credentials')) {
        _showError(Strings.incorrectPassword);
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
      final exists =
          await _authService.safeEmailExists(_emailController.text.trim());
      if (exists) {
        _setMode(AuthMode.signIn);
        _showError(Strings.switchToSignIn);
        return;
      }
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
      debugPrint('SignUp AuthException: ${e.message}');
      if (_isUserAlreadyExists(e)) {
        _setMode(AuthMode.signIn);
        _showError(Strings.switchToSignIn);
      } else {
        _showError(e.message);
      }
    } catch (e, stack) {
      debugPrint('SignUp error: $e\n$stack');
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF7F5F2),
                      Color(0xFFE9F1F0),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -120,
                top: -80,
                child: _GlowBlob(
                  size: 280,
                  color: const Color(0xFF00A6A6).withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                left: -100,
                bottom: -120,
                child: _GlowBlob(
                  size: 320,
                  color: const Color(0xFF1B3C59).withValues(alpha: 0.12),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 20 : 12),
                    child: Row(
                      children: [
                        if (isWide)
                          Expanded(
                            flex: 5,
                            child: _BrandPanel(
                              onDocs: _lastHelpUrl != null ? _openHelpUrl : null,
                            ),
                          ),
                        if (isWide) const SizedBox(width: 24),
                        Expanded(
                          flex: 6,
                          child: _AuthCard(
                            mode: _mode,
                            isLoading: _isLoading,
                            showGoogle: showGoogle,
                            strength: strength,
                            error: _error,
                            hasGoogleConfig: _authService.hasAnyGoogleClientId,
                            onCopyConfig: _copyGoogleConfig,
                            onDocs: _lastHelpUrl != null ? _openHelpUrl : null,
                            onModeChange: _setMode,
                            onSignIn: _signIn,
                            onSignUp: _signUp,
                            onGoogle: _signInWithGoogle,
                            onForgot: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RecoverPasswordPage(),
                              ),
                            ),
                            emailController: _emailController,
                            passwordController: _passwordController,
                            isCompact: !isWide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.mode,
    required this.isLoading,
    required this.showGoogle,
    required this.strength,
    required this.error,
    required this.hasGoogleConfig,
    required this.onCopyConfig,
    required this.onDocs,
    required this.onModeChange,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
    required this.onForgot,
    required this.emailController,
    required this.passwordController,
    required this.isCompact,
  });

  final AuthMode mode;
  final bool isLoading;
  final bool showGoogle;
  final _PasswordStrength strength;
  final String? error;
  final bool hasGoogleConfig;
  final VoidCallback onCopyConfig;
  final VoidCallback? onDocs;
  final ValueChanged<AuthMode> onModeChange;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onGoogle;
  final VoidCallback onForgot;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isSignUp = mode == AuthMode.signUp;
    final titleStyle = isCompact
        ? Theme.of(context).textTheme.headlineSmall
        : Theme.of(context).textTheme.headlineMedium;
    final fieldTheme = Theme.of(context).inputDecorationTheme.copyWith(
          isDense: isCompact,
          contentPadding: isCompact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 18 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Strings.appTitle,
              style: titleStyle?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isSignUp ? Strings.signUp : Strings.signIn,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: isCompact ? 12 : 18),
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
              selected: {mode},
              onSelectionChanged: (value) => onModeChange(value.first),
            ),
            SizedBox(height: isCompact ? 12 : 18),
            Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: fieldTheme,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: Strings.emailLabel),
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: Strings.passwordLabel,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isSignUp
                  ? Column(
                      key: const ValueKey('signup-strength'),
                      children: [
                        Text(
                          Strings.passwordRequirements,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isCompact ? 6 : 8),
                        LinearProgressIndicator(value: strength.progress),
                        SizedBox(height: isCompact ? 4 : 6),
                        Text(
                          strength.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SizedBox(height: isCompact ? 6 : 8),
                        _PasswordChecklist(password: passwordController.text),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('signin-spacer')),
            ),
            SizedBox(height: isCompact ? 10 : 12),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AuthErrorMessage(error!),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : (isSignUp ? onSignUp : onSignIn),
                child: Text(isSignUp ? Strings.signUp : Strings.signIn),
              ),
            ),
            SizedBox(height: isCompact ? 10 : 12),
            if (!isSignUp)
              TextButton(
                onPressed: onForgot,
                child: const Text(Strings.forgotPassword),
              ),
            if (showGoogle)
              OutlinedButton.icon(
                onPressed: isLoading ? null : onGoogle,
                icon: const Icon(Icons.login),
                label: const Text(Strings.continueWithGoogle),
              ),
            if (onDocs != null)
              TextButton(
                onPressed: onDocs,
                child: const Text(Strings.openDocs),
              ),
            if (hasGoogleConfig)
              TextButton(
                onPressed: onCopyConfig,
                child: const Text(Strings.copyGoogleConfig),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.onDocs});

  final VoidCallback? onDocs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.appTitle,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Une expérience fluide pour gérer vos comptes et documents.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _FeatureRow(
              title: 'Sécurité',
              description: 'Authentification moderne avec Supabase.',
            ),
            _FeatureRow(
              title: 'Productivité',
              description: 'Accès rapide sur desktop et mobile.',
            ),
            _FeatureRow(
              title: 'Confiance',
              description: 'Flux email vérifié et récupération intégrée.',
            ),
            const Spacer(),
            if (onDocs != null)
              TextButton.icon(
                onPressed: onDocs,
                icon: const Icon(Icons.open_in_new),
                label: const Text(Strings.openDocs),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
