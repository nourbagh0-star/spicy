/// Build-time configuration for services that are safe to expose to a client.
///
/// Supabase URLs and publishable/anon keys identify the project; they are not
/// server secrets. Server-side keys must never be included in this application.
abstract final class AppEnvironment {
  const AppEnvironment._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isSupabaseConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        supabasePublishableKey.trim().isNotEmpty;
  }
}
