import 'package:flutter/services.dart';

/// Strict Jordan **mobile** digits-only forms:
/// * Local: `07[789]` + 7 digits (10 digits)
/// * International: `9627[789]` + 7 digits (12 digits)
///
/// Normalize to E.164 `+9627XXXXXXXX` for Firebase.
class JordanPhone {
  JordanPhone._();

  /// Completed number (digits only — no spaces or symbols).
  ///
  /// Local `07…` (10 digits), international `9627…` (12), or **`7[789]` + 7
  /// digits** (9) when the leading `0` was omitted (`791234567` → same as `079…`).
  static final RegExp jordanMobileCompleteRegex = RegExp(
    r'^(07[789]\d{7}|9627[789]\d{7}|7[789]\d{7})$',
  );

  static final RegExp _jordanNineDigitWithoutLeadingZero = RegExp(r'^7[789]\d{7}$');

  /// Whether [digitsOnly] could still become a valid number as more digits arrive.
  static bool partialDigitsOnlyValid(String digitsOnly) {
    if (digitsOnly.isEmpty) return true;
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) return false;

    final first = digitsOnly[0];

    // Local without leading `0`: `77…`, `78…`, `79…` (9 digits total).
    if (first == '7') {
      if (digitsOnly.length >= 2) {
        final c = digitsOnly[1];
        if (c != '7' && c != '8' && c != '9') return false;
      }
      return digitsOnly.length <= 9;
    }

    // Local starting with `07`
    if (first == '0') {
      if (digitsOnly.length >= 2 && digitsOnly[1] != '7') return false;
      if (digitsOnly.length >= 3) {
        final c = digitsOnly[2];
        if (c != '7' && c != '8' && c != '9') return false;
      }
      return digitsOnly.length <= 10;
    }

    // International starting with `962`
    if (first != '9') return false;

    if (digitsOnly.length >= 2 && !digitsOnly.startsWith('96')) return false;
    if (digitsOnly.length >= 3 && !digitsOnly.startsWith('962')) return false;
    if (digitsOnly.length >= 4 && digitsOnly[3] != '7') return false;
    if (digitsOnly.length >= 5) {
      final c = digitsOnly[4];
      if (c != '7' && c != '8' && c != '9') return false;
    }
    return digitsOnly.length <= 12;
  }

  /// Immediate validation for `[0-9]` field (typically max 12, local clamped to 10).
  static String? liveDigitsOnlyError(String digitsOnly) {
    if (digitsOnly.isEmpty) return null;
    if (!partialDigitsOnlyValid(digitsOnly)) {
      return 'Use 079 · 078 · 077 plus 7 digits, or 96279 · 96278 · 96277 '
          '(12 digits).';
    }
    if (digitsOnly.startsWith('962') &&
        digitsOnly.length > 10 &&
        digitsOnly.length < 12) {
      return 'Jordan numbers starting with 962 need exactly 12 digits.';
    }
    if (digitsOnly.length == 9 ||
        digitsOnly.length == 10 ||
        digitsOnly.length == 12) {
      if (!jordanMobileCompleteRegex.hasMatch(digitsOnly)) {
        return 'Jordan mobile lookup must be 9 digits (79… without 0), 10 digits (07…), '
            'or 12 digits (962…) with a valid prefix.';
      }
    }
    return null;
  }

  /// Normalizes when [digitsOnly] already matches [jordanMobileCompleteRegex].
  /// Otherwise throws [FormatException] (validates before Firebase).
  static String normalizeValidatedDigitsOrThrow(String digitsOnly) {
    if (!jordanMobileCompleteRegex.hasMatch(digitsOnly)) {
      throw FormatException('Invalid Jordan mobile number');
    }
    if (digitsOnly.startsWith('07')) {
      return '+962${digitsOnly.substring(1)}';
    }
    if (digitsOnly.startsWith('962')) {
      return '+$digitsOnly';
    }
    if (_jordanNineDigitWithoutLeadingZero.hasMatch(digitsOnly)) {
      return '+962$digitsOnly';
    }
    throw FormatException('Invalid Jordan mobile number');
  }

  /// Returns E.164 `+9627XXXXXXXX` or `null` if invalid.
  static String? normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('00962')) {
      digits = digits.substring(2);
    }

    if (!jordanMobileCompleteRegex.hasMatch(digits)) return null;

    if (digits.startsWith('07')) {
      return '+962${digits.substring(1)}';
    }
    if (digits.startsWith('962')) {
      return '+$digits';
    }
    if (_jordanNineDigitWithoutLeadingZero.hasMatch(digits)) {
      return '+962$digits';
    }
    return null;
  }

  static String? validationMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your mobile number.';
    }
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 'Jordan mobile accepts digits only (no symbols or letters).';
    }
    final live = liveDigitsOnlyError(digitsOnly);
    if (live != null) return live;
    if (!jordanMobileCompleteRegex.hasMatch(digitsOnly)) {
      return 'Finish a valid 10-digit (07…) or 12-digit (962…) Jordan mobile.';
    }
    return null;
  }
}

/// Limits **local** `07…` numbers to exactly **10 digits** after the mandatory
/// [LengthLimitingTextInputFormatter(12)] caps raw input (helps pastes/spam).
///
/// Place **after** [LengthLimitingTextInputFormatter(12)].
class JordanMobileLocalTenDigitClampFormatter extends TextInputFormatter {
  const JordanMobileLocalTenDigitClampFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = newValue.text;
    if (t.isEmpty) return newValue;

    if (t.startsWith('0') && t.length > 10) {
      t = t.substring(0, 10);
      return TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
        composing: TextRange.empty,
      );
    }

    return newValue;
  }
}

/// Rejects keystrokes/pastes so the chip never contains a doomed prefix branch.
///
/// Compose after [FilteringTextInputFormatter.digitsOnly] and
/// [LengthLimitingTextInputFormatter(12)] as required.
class JordanMobilePrefixFormatter extends TextInputFormatter {
  const JordanMobilePrefixFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (JordanPhone.partialDigitsOnlyValid(t)) return newValue;
    return oldValue;
  }
}
