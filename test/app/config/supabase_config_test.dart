import 'package:evasion/app/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://example.supabase.co';
  const key = 'sb_publishable_example';

  test('exposes the given values', () {
    final config = SupabaseConfig(url: url, publishableKey: key);

    expect(config.url, url);
    expect(config.publishableKey, key);
  });

  test('rejects a missing url', () {
    expect(
      () => SupabaseConfig(url: '', publishableKey: key),
      throwsStateError,
    );
  });

  test('rejects a missing publishable key', () {
    expect(
      () => SupabaseConfig(url: url, publishableKey: ''),
      throwsStateError,
    );
  });

  test('rejects a secret key', () {
    expect(
      () => SupabaseConfig(url: url, publishableKey: 'sb_secret_example'),
      throwsStateError,
    );
  });

  test('fails when no value was injected at build time', () {
    expect(SupabaseConfig.fromEnvironment, throwsStateError);
  });
}
