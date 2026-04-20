import 'package:flutter_test/flutter_test.dart';
import 'package:bloodbank_donors/models/register_models.dart';

void main() {
  // =====================================================
  // UserType
  // =====================================================
  group('UserType enum', () {
    test('contains donor and bloodBank', () {
      expect(UserType.values.contains(UserType.donor), true);
      expect(UserType.values.contains(UserType.bloodBank), true);
    });
  });

  // =====================================================
  // RegisterResult
  // =====================================================
  group('RegisterResult', () {

    test('creates success result with defaults', () {
      final result = RegisterResult(success: true);

      expect(result.success, true);
      expect(result.emailVerified, false); // default
      expect(result.message, null);
      expect(result.errorTitle, null);
      expect(result.errorMessage, null);
    });

    test('creates success result with email verified', () {
      final result = RegisterResult(
        success: true,
        emailVerified: true,
        message: 'Registered successfully',
      );

      expect(result.success, true);
      expect(result.emailVerified, true);
      expect(result.message, 'Registered successfully');
    });

    test('creates error result correctly', () {
      final result = RegisterResult(
        success: false,
        errorTitle: 'Error',
        errorMessage: 'Something went wrong',
      );

      expect(result.success, false);
      expect(result.emailVerified, false); // still default
      expect(result.message, null);
      expect(result.errorTitle, 'Error');
      expect(result.errorMessage, 'Something went wrong');
    });

    test('allows partial data', () {
      final result = RegisterResult(
        success: false,
        message: 'Partial',
      );

      expect(result.success, false);
      expect(result.message, 'Partial');
      expect(result.errorTitle, null);
      expect(result.errorMessage, null);
    });

  });
}