import 'package:evasion/features/posts/domain/post.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row of `posts_public`, with [changes] applied.
Map<String, dynamic> publicRow([Map<String, dynamic> changes = const {}]) => {
  'id': 'post-1',
  'author_id': 'user-1',
  'image_path': 'user-1/a.jpg',
  'caption': 'Sunset',
  'latitude': 46.5191,
  'longitude': 6.5668,
  'location_precision': 'fuzzy',
  'audience': 'everyone',
  'created_at': '2026-11-25T10:00:00+00:00',
  'expires_at': '2026-11-26T10:00:00+00:00',
  ...changes,
};

void main() {
  test('reads a row of posts_public', () {
    final post = postFromRow(publicRow())!;

    expect(post.id, 'post-1');
    expect(post.authorId, 'user-1');
    expect(post.imagePath, 'user-1/a.jpg');
    expect(post.caption, 'Sunset');
    expect((post.latitude, post.longitude), (46.5191, 6.5668));
    expect(post.precision, PostPrecision.fuzzy);
    expect(post.audience, PostAudience.everyone);
    expect(post.createdAt, DateTime.utc(2026, 11, 25, 10));
    expect(post.expiresAt, DateTime.utc(2026, 11, 26, 10));
    expect(post.isPinned, isFalse);
    expect(post.authorName, isNull);
  });

  test('reads the extra columns of the map feed', () {
    final post = postFromRow({
      ...publicRow({'location_precision': 'exact'})..remove('audience'),
      'author_name': 'Alice',
      'author_avatar_path': 'user-1/avatar.jpg',
      'is_pinned': true,
    })!;

    expect(post.precision, PostPrecision.exact);
    expect(post.audience, isNull);
    expect(post.authorName, 'Alice');
    expect(post.authorAvatarPath, 'user-1/avatar.jpg');
    expect(post.isPinned, isTrue);
  });

  test('accepts whole numbers as coordinates', () {
    final post = postFromRow(publicRow({'latitude': 46, 'longitude': 6}))!;

    expect((post.latitude, post.longitude), (46.0, 6.0));
  });

  test('skips a post of a precision this app does not know', () {
    expect(postFromRow(publicRow({'location_precision': 'street'})), isNull);
  });

  test('keeps a post of an unknown audience, without its audience', () {
    final post = postFromRow(publicRow({'audience': 'family'}))!;

    expect(post.audience, isNull);
  });
}
