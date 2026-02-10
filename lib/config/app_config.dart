class AppConfig {
  static const supabaseRedirectScheme = 'com.profilias.oran.profilias';
  static const supabaseRedirectHost = 'login-callback';
  static const supabaseRedirectUrl =
      '$supabaseRedirectScheme://$supabaseRedirectHost/';

  static const supabaseGoogleHelpUrl =
      'https://supabase.com/docs/guides/auth/social-login/auth-google';

  // Google OAuth client IDs (set as needed).
  static const googleWebClientId =
      '531827281606-nrr3nisu9oah0s032g9vh01mjve3415c.apps.googleusercontent.com';
  static const googleIosClientId = '';
}
