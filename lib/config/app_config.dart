class AppConfig {
  static const supabaseRedirectScheme = 'com.profilias.oran.profilias';
  static const supabaseRedirectHost = 'login-callback';
  static const supabaseRedirectUrl =
      '$supabaseRedirectScheme://$supabaseRedirectHost/';

  static const supabaseGoogleHelpUrl =
      'https://supabase.com/docs/guides/auth/social-login/auth-google';
}
