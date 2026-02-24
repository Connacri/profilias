import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../strings.dart';
import '../widgets/app_buttons.dart';
import '../widgets/auth_error_message.dart';
import 'reset_password_page.dart';
import '../widgets/responsive_layout.dart';

class RecoverPasswordPage extends StatefulWidget {
  const RecoverPasswordPage({super.key});

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) {
        return;
      }
      if (event.event == AuthChangeEvent.passwordRecovery) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
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

  Future<void> _recoverPassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      await _authService.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.resetEmailSent)),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.recoverPassword)),
      body: ResponsiveLayout(
        maxWidth: 520,
        padding: const EdgeInsets.all(16),
        builder: (context, info) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: Strings.emailLabel),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AuthErrorMessage(_error!),
                ),
              AppPrimaryButton(
                onPressed: _isLoading ? null : _recoverPassword,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(Strings.recoverPassword),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(Strings.backToSignIn),
              ),
            ],
          );
        },
      ),
    );
  }
}
