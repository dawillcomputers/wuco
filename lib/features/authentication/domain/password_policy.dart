/// Configurable password rules, applied identically by the UI strength meter
/// and by repository validation so the two can never disagree.
abstract final class PasswordPolicy {
  static const minLength = 8;
  static const requireUppercase = true;
  static const requireLowercase = true;
  static const requireDigit = true;
  static const requireSymbol = true;

  static bool hasUppercase(String value) => RegExp('[A-Z]').hasMatch(value);
  static bool hasLowercase(String value) => RegExp('[a-z]').hasMatch(value);
  static bool hasDigit(String value) => RegExp('[0-9]').hasMatch(value);
  static bool hasSymbol(String value) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/+=~`;' "']").hasMatch(value);

  /// Individual rules and whether [value] satisfies them, for the checklist UI.
  static List<({String label, bool satisfied})> checklist(String value) => [
    (label: 'At least $minLength characters', satisfied: value.length >= minLength),
    if (requireUppercase)
      (label: 'One uppercase letter', satisfied: hasUppercase(value)),
    if (requireLowercase)
      (label: 'One lowercase letter', satisfied: hasLowercase(value)),
    if (requireDigit) (label: 'One number', satisfied: hasDigit(value)),
    if (requireSymbol) (label: 'One symbol', satisfied: hasSymbol(value)),
  ];

  static bool isValid(String value) =>
      checklist(value).every((rule) => rule.satisfied);

  /// 0.0–1.0, driving the strength bar.
  static double strength(String value) {
    if (value.isEmpty) return 0;
    final rules = checklist(value);
    final met = rules.where((rule) => rule.satisfied).length;
    var score = met / rules.length;
    // Length beyond the minimum earns a little extra credit.
    if (value.length >= 12 && score >= .8) score = 1;
    return score.clamp(0, 1);
  }

  static String strengthLabel(String value) {
    final score = strength(value);
    if (value.isEmpty) return '';
    if (score < .4) return 'Weak';
    if (score < .7) return 'Fair';
    if (score < 1) return 'Strong';
    return 'Excellent';
  }

  /// Validator message, or null when acceptable.
  static String? validate(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Please enter your password.';
    if (!isValid(text)) {
      final missing = checklist(
        text,
      ).where((rule) => !rule.satisfied).map((rule) => rule.label.toLowerCase());
      return 'Password needs: ${missing.join(', ')}.';
    }
    return null;
  }
}
