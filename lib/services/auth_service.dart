import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../strings.dart';

class AuthService {

  final SupabaseClient _client = Supabase.instance.client;

  String get webClientId => AppConfig.googleWebClientId;
  String get iosClientId => AppConfig.googleIosClientId;

  bool get hasAnyGoogleClientId =>
      webClientId.isNotEmpty || iosClientId.isNotEmpty;

  bool _isPlaceholderClientId(String value) {
    return value.isEmpty ||
        value.contains('YOUR_WEB_CLIENT_ID') ||
        value.contains('YOUR_IOS_CLIENT_ID');
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        if (_isPlaceholderClientId(webClientId)) {
          throw StateError(
            Strings.invalidWebClientId,
          );
        }
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            _isPlaceholderClientId(iosClientId)) {
          throw StateError(
            Strings.invalidIosClientId,
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
          throw StateError(Strings.missingGoogleToken);
        }

        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: AppConfig.supabaseRedirectUrl,
        );
        return;
      case TargetPlatform.fuchsia:
        throw StateError(Strings.unsupportedPlatform);
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConfig.supabaseRedirectUrl,
    );
  }

  Future<void> resendSignupEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: AppConfig.supabaseRedirectUrl,
    );
  }

  Future<void> updateDisplayName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': trimmed}),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
