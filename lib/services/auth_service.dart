import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const supabaseRedirectScheme = 'com.profilias.oran.profilias';
  static const supabaseRedirectHost = 'login-callback';
  static const supabaseRedirectUrl =
      '$supabaseRedirectScheme://$supabaseRedirectHost/';

  final SupabaseClient _client = Supabase.instance.client;

  String get webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  String get iosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

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
          redirectTo: supabaseRedirectUrl,
        );
        return;
      case TargetPlatform.fuchsia:
        throw StateError('Plateforme non supportée.');
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

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
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
}
