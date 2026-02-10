import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:functions_client/functions_client.dart';
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

  Future<bool> emailExists(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final response = await _client.functions.invoke(
      'check-email-exists',
      body: {'email': trimmed},
    );
    debugPrint('check-email-exists status=${response.status} data=${response.data}');
    if (response.status >= 400) {
      throw AuthException(
        response.data?['error']?.toString() ??
            'Email check failed (${response.status}).',
      );
    }
    final data = response.data;
    if (data is Map && data['exists'] is bool) {
      return data['exists'] as bool;
    }
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map && decoded['exists'] is bool) {
        return decoded['exists'] as bool;
      }
    }
    return false;
  }

  Future<bool> safeEmailExists(String email) async {
    try {
      return await emailExists(email);
    } on FunctionException catch (e) {
      throw AuthException(
        'Email check failed (${e.status}): ${e.details ?? e.reasonPhrase ?? 'unknown'}',
      );
    }
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

  Future<void> ensureProfileCreated(User user) async {
    final profileId = user.id;
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', profileId)
        .maybeSingle();
    if (existing != null) {
      return;
    }
    final payload = <String, dynamic>{
      'id': profileId,
      'email': user.email,
      if (user.userMetadata?['full_name'] != null)
        'full_name': user.userMetadata?['full_name'],
      if (user.userMetadata?['avatar_url'] != null)
        'photoProfil_url': user.userMetadata?['avatar_url'],
      if (user.userMetadata?['cover_url'] != null)
        'cover_url': user.userMetadata?['cover_url'],
    };
    await _client.from('profiles').insert(payload);
  }
}
