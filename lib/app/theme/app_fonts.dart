import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Font families bundled in `assets/fonts/` and declared in `pubspec.yaml`.
///
/// Static weights cut from the variable fonts of Google Fonts, so that every
/// platform draws the same weight: Bricolage Grotesque 500, 700 and 800
/// (optical size 48), Inter 400, 500 and 600 (optical size 14).
abstract final class AppFonts {
  /// Headings: warm and a little raw.
  static const String display = 'BricolageGrotesque';

  /// Body text: readable at every size.
  static const String body = 'Inter';

  /// Adds the fonts' SIL Open Font License to the app's licence page, as
  /// the licence requires.
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      for (final (family, folder) in [
        ('Bricolage Grotesque', 'bricolage_grotesque'),
        ('Inter', 'inter'),
      ]) {
        yield LicenseEntryWithLineBreaks([
          family,
        ], await rootBundle.loadString('assets/fonts/$folder/OFL.txt'));
      }
    });
  }
}
