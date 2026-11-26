class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where the password-reset email link sends the person. Must also be listed under
  /// Supabase > Authentication > URL Configuration > Redirect URLs.
  static const resetRedirect = String.fromEnvironment('RESET_REDIRECT', defaultValue: 'io.tutobridge.app://reset-password');
}
