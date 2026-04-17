/// Jordan mobile numbers: national form `07XXXXXXXX` (10 digits) or
/// international `+9627XXXXXXXX` (country code 962 + 9-digit mobile without leading 0).
class JordanPhone {
  JordanPhone._();

  /// Returns E.164 string `+9627xxxxxxxx` or null if invalid.
  static String? normalize(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s\-.]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('00962')) s = '+962${s.substring(5)}';
    if (s.startsWith('962') && !s.startsWith('+962')) {
      s = '+962${s.substring(3)}';
    }
    if (s.startsWith('+962')) {
      final rest = s.substring(4);
      if (RegExp(r'^7\d{8}$').hasMatch(rest)) return '+962$rest';
      return null;
    }
    if (RegExp(r'^07\d{8}$').hasMatch(s)) return '+962${s.substring(1)}';
    if (RegExp(r'^7\d{8}$').hasMatch(s)) return '+962$s';
    return null;
  }

  static String? validationMessage(String raw) {
    if (raw.trim().isEmpty) {
      return 'Please enter your mobile number.';
    }
    if (normalize(raw) == null) {
      return 'Enter a valid Jordan mobile number (e.g. 0791234567 or +962791234567).';
    }
    return null;
  }
}
