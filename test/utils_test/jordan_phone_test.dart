import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/utils/jordan_phone.dart';

void main() {
  group('JordanPhone.normalize', () {
    test('accepts 07XXXXXXXX', () {
      expect(JordanPhone.normalize('0791234567'), '+962791234567');
    });

    test('accepts +962 form', () {
      expect(JordanPhone.normalize('+962 79 123 4567'), '+962791234567');
    });

    test('accepts 962 without plus', () {
      expect(JordanPhone.normalize('962791234567'), '+962791234567');
    });

    test('accepts 00962 prefix', () {
      expect(JordanPhone.normalize('00962791234567'), '+962791234567');
    });

    test('accepts 9 digits starting with 7', () {
      expect(JordanPhone.normalize('791234567'), '+962791234567');
    });

    test('rejects wrong length', () {
      expect(JordanPhone.normalize('07912345'), isNull);
    });

    test('rejects landline-looking prefix', () {
      expect(JordanPhone.normalize('0612345678'), isNull);
    });
  });

  group('JordanPhone.validationMessage', () {
    test('empty', () {
      expect(JordanPhone.validationMessage(''), isNotNull);
    });

    test('valid', () {
      expect(JordanPhone.validationMessage('0791234567'), isNull);
    });
  });
}
