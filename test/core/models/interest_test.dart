import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/interest.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the codes match the list accepted by the server', () {
    expect(Interest.values.map((interest) => interest.code), [
      'sport',
      'music',
      'movies',
      'reading',
      'travel',
      'cooking',
      'gaming',
      'art',
      'nature',
      'nightlife',
      'technology',
      'photography',
      'volunteering',
    ]);
  });

  test('a known code gives its interest', () {
    expect(Interest.fromCode('music'), Interest.music);
  });

  test('codes unknown to this version of the app are skipped', () {
    expect(Interest.fromCode('skydiving'), isNull);
    expect(Interest.fromCodes(['sport', 'skydiving', 'art']), [
      Interest.sport,
      Interest.art,
    ]);
  });

  test('every interest has its own French label', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));
    final labels = Interest.values.map((interest) => interest.label(l10n));

    expect(labels, everyElement(isNotEmpty));
    expect(labels.toSet(), hasLength(Interest.values.length));
  });

  test('a page can hold every interest up to the limit', () {
    expect(
      Interest.values.length,
      greaterThanOrEqualTo(BusinessRules.interestsMaxPerPage),
    );
  });
}
