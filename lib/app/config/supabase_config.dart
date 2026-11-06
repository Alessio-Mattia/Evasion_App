/// Connection settings of the Supabase project used by the current environment.
class SupabaseConfig {
  /// Throws a [StateError] when a value is missing or when [publishableKey] is
  /// a secret key, which must never ship in the app.
  factory SupabaseConfig({
    required String url,
    required String publishableKey,
  }) {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required: '
        'run with --dart-define-from-file=env/<environment>.json.',
      );
    }
    if (publishableKey.startsWith('sb_secret_')) {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY contains a secret key: '
        'use the publishable key instead.',
      );
    }
    return SupabaseConfig._(url, publishableKey);
  }

  /// Reads the values injected at build time by `--dart-define-from-file`.
  factory SupabaseConfig.fromEnvironment() => SupabaseConfig(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  const SupabaseConfig._(this.url, this.publishableKey);

  final String url;
  final String publishableKey;
}
