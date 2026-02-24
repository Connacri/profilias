import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../strings.dart';
import '../widgets/app_buttons.dart';
import '../widgets/auth_error_message.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  static const _resendLimitPerDay = 3;
  static const _resendCooldownSeconds = 30;

  final _authService = AuthService();
  bool _isLoading = false;
  bool _isReturning = false;
  bool _isOpeningMailbox = false;
  String? _error;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureMinDelay(Stopwatch stopwatch) async {
    const minDelay = Duration(milliseconds: 400);
    stopwatch.stop();
    final remaining = minDelay - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<bool> _canResendToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('email_resend_date');
    var count = prefs.getInt('email_resend_count') ?? 0;

    if (storedDate != today) {
      count = 0;
      await prefs.setString('email_resend_date', today);
      await prefs.setInt('email_resend_count', count);
    }

    return count < _resendLimitPerDay;
  }

  Future<void> _incrementResendCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('email_resend_date');
    var count = prefs.getInt('email_resend_count') ?? 0;

    if (storedDate != today) {
      count = 0;
      await prefs.setString('email_resend_date', today);
    }

    await prefs.setInt('email_resend_count', count + 1);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownLeft <= 1) {
        timer.cancel();
        setState(() => _cooldownLeft = 0);
      } else {
        setState(() => _cooldownLeft -= 1);
      }
    });
  }

  Future<void> _resendEmail() async {
    if (_cooldownLeft > 0) {
      return;
    }
    if (!await _canResendToday()) {
      setState(() => _error = Strings.resendLimitReached);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      await _authService.resendSignupEmail(widget.email);
      await _incrementResendCount();
      _startCooldown();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = Strings.connectionError);
    } finally {
      await _ensureMinDelay(stopwatch);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _returnToSignIn() async {
    if (_isReturning) {
      return;
    }
    setState(() {
      _isReturning = true;
      _error = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      Navigator.of(context).pop();
    } finally {
      await _ensureMinDelay(stopwatch);
      if (mounted) {
        setState(() => _isReturning = false);
      }
    }
  }

  Future<void> _openMailbox() async {
    if (_isOpeningMailbox) {
      return;
    }
    setState(() {
      _isOpeningMailbox = true;
      _error = null;
    });
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('mailto:');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _ensureMinDelay(stopwatch);
    if (mounted) {
      setState(() => _isOpeningMailbox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.awaitingEmailTitle)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9F5F0), Color(0xFFEAF3F1)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 18 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AuthErrorMessage(_error!),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: AppPrimaryButton(
                        onPressed:
                            _isLoading || _isReturning ? null : _returnToSignIn,
                        child: _isReturning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(Strings.trySignIn),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _resendEmail,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _cooldownLeft > 0
                                    ? '${Strings.resendEmailIn} ${_cooldownLeft}s'
                                    : Strings.resendEmail,
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          _isOpeningMailbox ? null : _openMailbox,
                      child: _isOpeningMailbox
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(Strings.openMailbox),
                    ),
                  ],
                ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
