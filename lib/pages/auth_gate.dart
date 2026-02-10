import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'home_page.dart';
import 'reset_password_page.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  Future<void>? _profileFuture;
  String? _profileUserId;

  void _ensureProfile(User user) {
    if (_profileUserId == user.id && _profileFuture != null) {
      return;
    }
    _profileUserId = user.id;
    _profileFuture = _authService.ensureProfileCreated(user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordPage();
        }
        final session = snapshot.data?.session;
        if (session == null) {
          return const AuthPage();
        }
        _ensureProfile(session.user);
        return FutureBuilder<void>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return const AuthPage();
            }
            return HomePage(email: session.user.email ?? 'Utilisateur');
          },
        );
      },
    );
  }
}
