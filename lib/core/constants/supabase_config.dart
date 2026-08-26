class SupabaseConfig {
  SupabaseConfig._();

  /// Pass your Supabase project URL via --dart-define=SUPABASE_URL=... or replace directly.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  /// Pass your Supabase anon key via --dart-define=SUPABASE_ANON_KEY=... or replace directly.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );
}
