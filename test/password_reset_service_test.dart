import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/password_reset_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseAuth mockAuth;
  late PasswordResetService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    service = PasswordResetService(auth: mockAuth);
  });

              //TEST CASES//

       
      /// SUCCESS ///
  test('sends reset link successfully', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenAnswer(
              (_) async => Future.value());

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, true);
    expect(result.message,"Password reset link has been sent to your email.");

    verify(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).called(1);
  });

        /// USER NOT FOUND ///
  test('returns message when user not found', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenThrow(
               FirebaseAuthException(code: "user-not-found"),);

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"No account found with this email address.");
  });

          /// INVALID EMAIL ///
  test('returns message when email invalid', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),
              )).thenThrow(FirebaseAuthException(code: "invalid-email"),);

    final result = await service.sendPasswordResetEmail("bad_email");

    expect(result.success, false);
    expect(result.message, "Invalid email address.");
  });

          /// TOO MANY REQUESTS ///
  test('returns too many requests message', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),
              )).thenThrow(FirebaseAuthException(code: "too-many-requests"),);

    final result =await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"Too many requests. Please try again later.");
  });

          /// OTHER ERROR ///
  test('returns failure message', () async {
    when(() => mockAuth.sendPasswordResetEmail(email: any(named: "email"),)).thenThrow(Exception());

    final result = await service.sendPasswordResetEmail("test@test.com");

    expect(result.success, false);
    expect(result.message,"Something went wrong. Please try again.");
  });

  /// EMPTY EMAIL
  test('returns message if email empty', () async {
    final result = await service.sendPasswordResetEmail("");

    expect(result.success, false);
    expect(result.message, "Please enter your email address.");
  });











}