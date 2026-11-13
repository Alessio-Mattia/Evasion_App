import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileDetails details({
  String displayName = 'Alex',
  String occupation = '',
  String university = '',
  String bio = '',
}) => ProfileDetails(
  displayName: displayName,
  occupation: occupation,
  university: university,
  bio: bio,
);

void main() {
  test('trims the texts and turns blank optional ones into null', () {
    final typed = details(
      displayName: '  Alex ',
      occupation: ' Étudiante ',
      university: '   ',
      bio: '\nSalut !\n',
    );

    expect(typed.displayName, 'Alex');
    expect(typed.occupation, 'Étudiante');
    expect(typed.university, isNull);
    expect(typed.bio, 'Salut !');
  });

  test('equals the stored details when only spaces were added', () {
    const profile = Profile(
      id: 'user-1',
      isComplete: true,
      isStudentVerified: false,
      displayName: 'Alex',
      bio: 'Salut !',
    );

    expect(
      details(displayName: 'Alex ', bio: ' Salut !'),
      ProfileDetails.of(profile),
    );
    expect(details(bio: 'Salut'), isNot(ProfileDetails.of(profile)));
  });

  group('isValid', () {
    test('accepts usual details', () {
      expect(details(occupation: 'Biologie').isValid, isTrue);
    });

    test('refuses a blank name', () {
      expect(details(displayName: '  ').isValid, isFalse);
    });

    test('refuses texts over their limits', () {
      expect(details(displayName: 'a' * 51).isValid, isFalse);
      expect(details(occupation: 'a' * 101).isValid, isFalse);
      expect(details(university: 'a' * 101).isValid, isFalse);
      expect(details(bio: 'a' * 501).isValid, isFalse);
      expect(details(bio: 'a' * 500).isValid, isTrue);
    });
  });
}
