import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a complete row as returned by Supabase', () {
    final profile = Profile.fromJson(const {
      'id': 'user-1',
      'display_name': 'Alex',
      'birth_date': '2000-05-17',
      'gender': 'woman',
      'avatar_path': 'user-1/avatar.jpg',
      'is_student_verified': true,
      'is_complete': true,
      'occupation': 'Étudiante',
      'university': 'UNIGE',
      'bio': 'Salut !',
    });

    expect(profile.displayName, 'Alex');
    expect(profile.occupation, 'Étudiante');
    expect(profile.university, 'UNIGE');
    expect(profile.bio, 'Salut !');
    expect(profile.birthDate, DateTime(2000, 5, 17));
    expect(profile.gender, Gender.woman);
    expect(profile.isStudentVerified, isTrue);
    expect(profile.isComplete, isTrue);
  });

  test('reads a profile right after sign-up, with empty fields', () {
    final profile = Profile.fromJson(const {
      'id': 'user-1',
      'display_name': null,
      'birth_date': null,
      'gender': null,
      'avatar_path': null,
      'is_student_verified': false,
      'is_complete': false,
    });

    expect(profile.displayName, isNull);
    expect(profile.birthDate, isNull);
    expect(profile.gender, isNull);
    expect(profile.isComplete, isFalse);
  });

  test('every gender matches a value allowed by the database', () {
    expect(Gender.values.map((g) => g.databaseValue), [
      'woman',
      'man',
      'other',
    ]);
  });
}
