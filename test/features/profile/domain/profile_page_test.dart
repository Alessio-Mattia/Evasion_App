import 'package:evasion/core/models/interest.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(
  String type,
  Map<String, dynamic> content, {
  String? imagePath,
}) => {
  'id': 'page-1',
  'position': 2,
  'type': type,
  'content': content,
  'image_path': imagePath,
};

void main() {
  test('reads a text page', () {
    expect(
      profilePageFromRow(row('text', {'text': 'Bonjour'})),
      const ProfilePage.text(id: 'page-1', position: 2, text: 'Bonjour'),
    );
  });

  test('reads a photo page, with or without a caption', () {
    expect(
      profilePageFromRow(
        row('photo', {'caption': 'Au lac'}, imagePath: 'user-1/a.jpg'),
      ),
      const ProfilePage.photo(
        id: 'page-1',
        position: 2,
        imagePath: 'user-1/a.jpg',
        caption: 'Au lac',
      ),
    );
    expect(
      profilePageFromRow(row('photo', {}, imagePath: 'user-1/a.jpg')),
      isA<PhotoPage>().having((page) => page.caption, 'caption', isNull),
    );
  });

  test('reads interests, skipping codes this version does not know', () {
    expect(
      profilePageFromRow(
        row('interests', {
          'interests': ['music', 'skydiving', 'travel'],
        }),
      ),
      const ProfilePage.interests(
        id: 'page-1',
        position: 2,
        interests: [Interest.music, Interest.travel],
      ),
    );
  });

  test('skips a page it cannot show instead of failing', () {
    expect(profilePageFromRow(row('video', {'url': 'x'})), isNull);
    expect(profilePageFromRow(row('text', {})), isNull);
    expect(profilePageFromRow(row('photo', {})), isNull);
    expect(
      profilePageFromRow(
        row('interests', {
          'interests': ['skydiving'],
        }),
      ),
      isNull,
    );
  });
}
