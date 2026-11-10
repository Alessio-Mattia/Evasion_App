import 'package:evasion/core/config/business_rules.dart';

/// Light format check, to catch typos before calling the server. The real
/// proof that the address exists is the code it receives.
bool isValidEmail(String email) =>
    _emailPattern.hasMatch(normalizeEmail(email));

/// Email as stored by the server: no surrounding spaces, lower case.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Whether [code] has exactly the expected number of digits.
bool isValidSignInCode(String code) => _codePattern.hasMatch(code.trim());

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _codePattern = RegExp('^[0-9]{${BusinessRules.signInCodeLength}}\$');
