import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/shared/utils/jordan_phone.dart';

void main() {
  group('partialDigitsOnlyValid', () {
    test('allows building 079 progressively', () {
      expect(JordanPhone.partialDigitsOnlyValid('0'), true);
      expect(JordanPhone.partialDigitsOnlyValid('07'), true);
      expect(JordanPhone.partialDigitsOnlyValid('079'), true);
      expect(JordanPhone.partialDigitsOnlyValid('0791234567'), true);
    });

    test('rejects075 early', () {
      expect(JordanPhone.partialDigitsOnlyValid('075'), false);
    });

    test('allows international build', () {
      expect(JordanPhone.partialDigitsOnlyValid('962'), true);
      expect(JordanPhone.partialDigitsOnlyValid('9627'), true);
      expect(JordanPhone.partialDigitsOnlyValid('96279'), true);
      expect(JordanPhone.partialDigitsOnlyValid('962791234567'), true);
    });

    test('rejects long local', () {
      expect(JordanPhone.partialDigitsOnlyValid('07912345678'), false);
    });

    test('rejects digit 8 first char', () {
      expect(JordanPhone.partialDigitsOnlyValid('8'), false);
    });
  });

  group('JordanMobileLocalTenDigitClampFormatter', () {
    const clamp = JordanMobileLocalTenDigitClampFormatter();

    test('clips local paste exceeding 10 digits', () {
      final nv = TextEditingValue(text: '079123456789');
      expect(clamp.formatEditUpdate(TextEditingValue.empty, nv).text,
          '0791234567');
    });

    test('leaves962 at 12 untouched', () {
      const nv = TextEditingValue(text: '962791234567');
      expect(clamp.formatEditUpdate(TextEditingValue.empty, nv), nv);
    });
  });

  group('normalizeValidatedDigitsOrThrow', () {
    test('returns E164 when valid', () {
      expect(
        JordanPhone.normalizeValidatedDigitsOrThrow('0791234567'),
        '+962791234567',
      );
    });

    test('throws when invalid prefix', () {
      expect(
        () => JordanPhone.normalizeValidatedDigitsOrThrow('0751234567'),
        throwsFormatException,
      );
    });
  });

  group('JordanMobilePrefixFormatter', () {
    const f = JordanMobilePrefixFormatter();

    test('allows 079 path', () {
      final nv = TextEditingValue(text: '0791234567');
      expect(
        f.formatEditUpdate(TextEditingValue.empty, nv),
        nv,
      );
    });

    test('blocks075 after 07', () {
      const oldVal = TextEditingValue(
        text: '07',
        selection: TextSelection.collapsed(offset: 2),
      );
      const bad = TextEditingValue(text: '075');
      expect(f.formatEditUpdate(oldVal, bad), oldVal);
    });
  });

  group('JordanPhone.normalize strict Jordan mobile', () {
    test('079 local', () {
      expect(JordanPhone.normalize('0791234567'), '+962791234567');
    });

    test('078 local', () {
      expect(JordanPhone.normalize('0781234567'), '+962781234567');
    });

    test('077 local', () {
      expect(JordanPhone.normalize('0771234567'), '+962771234567');
    });

    test('962 without plus', () {
      expect(JordanPhone.normalize('962791234567'), '+962791234567');
    });

    test('+962 form with separators', () {
      expect(JordanPhone.normalize('+962 79 123 4567'), '+962791234567');
    });

    test('00962 prefix', () {
      expect(JordanPhone.normalize('00962791234567'), '+962791234567');
    });

    test('rejects075 prefix', () {
      expect(JordanPhone.normalize('0751234567'), isNull);
    });

    test('rejects non-Jordan country (971)', () {
      expect(JordanPhone.normalize('+971501234567'), isNull);
    });

    test('771234567 without leading 0 (same as 077…)', () {
      expect(JordanPhone.normalize('771234567'), '+962771234567');
    });

    test('791234567 without leading 0 (same as 079…)', () {
      expect(JordanPhone.normalize('791234567'), '+962791234567');
    });

    test('rejects wrong length local', () {
      expect(JordanPhone.normalize('079123456'), isNull);
    });

    test('rejects generic US-like', () {
      expect(JordanPhone.normalize('1234567890'), isNull);
    });

    test('rejects landline-style', () {
      expect(JordanPhone.normalize('0612345678'), isNull);
    });
  });

  group('JordanPhone.validationMessage', () {
    test('empty', () {
      expect(JordanPhone.validationMessage(''), isNotNull);
    });

    test('valid 079', () {
      expect(JordanPhone.validationMessage('0791234567'), isNull);
    });

    test('invalid returns message', () {
      expect(JordanPhone.validationMessage('0751234567'), isNotNull);
    });
  });
}
