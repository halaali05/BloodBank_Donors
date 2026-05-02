import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/phone_auth_service.dart';

// ================= MOCKS =================

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class FakeAuthCredential extends Fake implements AuthCredential {}

class FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late PhoneAuthService service;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(FakePhoneAuthCredential());
     registerFallbackValue(Duration(seconds: 60));
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    service = PhoneAuthService(firebaseAuth: mockAuth);
  });

  // ================= SEND OTP =================

  group('sendSmsOtpToLinkCurrentUser', () {
    test('throws if phone number invalid', () async {
      expect(
        () => service.sendSmsOtpToLinkCurrentUser(
          phoneNumber: '0791234567',
          onCodeSent: () {},
          onVerificationFailed: (_) {},
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('calls onVerificationFailed when no user', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      FirebaseAuthException? error;

      await service.sendSmsOtpToLinkCurrentUser(
        phoneNumber: '+962791234567',
        onCodeSent: () {},
        onVerificationFailed: (e) => error = e,
      );

      expect(error, isNotNull);
      expect(error!.code, 'no-current-user');
    });

    test('codeSent flow works and stores verificationId', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      late void Function(String, int?) capturedCodeSent;

      when(() => mockAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            timeout: any(named: 'timeout'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted:
                any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout:
                any(named: 'codeAutoRetrievalTimeout'),
          )).thenAnswer((invocation) async {
        capturedCodeSent =
            invocation.namedArguments[#codeSent] as void Function(String, int?);
      });

      bool called = false;

      await service.sendSmsOtpToLinkCurrentUser(
        phoneNumber: '+962791234567',
        onCodeSent: () => called = true,
        onVerificationFailed: (_) {},
      );

      // simulate Firebase callback
      capturedCodeSent('testId', 123);

      expect(service.linkVerificationId, 'testId');
      expect(service.hasPendingLinkVerification, true);
      expect(called, true);
    });
  });

  // ================= VERIFY OTP =================

  group('verifyOtpAndLink', () {
    test('throws if no verificationId', () async {
      expect(
        () => service.verifyOtpAndLink(smsCode: '123456'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('throws if smsCode empty', () async {
      // simulate flow instead of accessing private field
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      late void Function(String, int?) codeSent;

      when(() => mockAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            timeout: any(named: 'timeout'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted:
                any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout:
                any(named: 'codeAutoRetrievalTimeout'),
          )).thenAnswer((invocation) async {
        codeSent =
            invocation.namedArguments[#codeSent] as void Function(String, int?);
      });

      await service.sendSmsOtpToLinkCurrentUser(
        phoneNumber: '+962791234567',
        onCodeSent: () {},
        onVerificationFailed: (_) {},
      );

      codeSent('id', null);

      expect(
        () => service.verifyOtpAndLink(smsCode: ''),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('links successfully and clears state', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final mockCredential = MockUserCredential();

      when(() => mockUser.linkWithCredential(any()))
          .thenAnswer((_) async => mockCredential);

      late void Function(String, int?) codeSent;

      when(() => mockAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            timeout: any(named: 'timeout'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted:
                any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout:
                any(named: 'codeAutoRetrievalTimeout'),
          )).thenAnswer((invocation) async {
        codeSent =
            invocation.namedArguments[#codeSent] as void Function(String, int?);
      });

      await service.sendSmsOtpToLinkCurrentUser(
        phoneNumber: '+962791234567',
        onCodeSent: () {},
        onVerificationFailed: (_) {},
      );

      codeSent('id', null);

      final result =
          await service.verifyOtpAndLink(smsCode: '123456');

      expect(result, mockCredential);
      expect(service.linkVerificationId, null);
      expect(service.hasPendingLinkVerification, false);
    });
  });

  // ================= AUTO LINK =================

  group('auto verification', () {
    test('verificationCompleted triggers auto link', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final mockCredential = MockUserCredential();

      when(() => mockUser.linkWithCredential(any()))
          .thenAnswer((_) async => mockCredential);

      late void Function(PhoneAuthCredential)
          capturedVerificationCompleted;

      when(() => mockAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            timeout: any(named: 'timeout'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted:
                any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout:
                any(named: 'codeAutoRetrievalTimeout'),
          )).thenAnswer((invocation) async {
        capturedVerificationCompleted =
            invocation.namedArguments[#verificationCompleted]
                as void Function(PhoneAuthCredential);
      });

      UserCredential? linked;

      await service.sendSmsOtpToLinkCurrentUser(
        phoneNumber: '+962791234567',
        onCodeSent: () {},
        onVerificationFailed: (_) {},
        onAutoLinked: (uc) => linked = uc,
      );

      final fakeCredential = PhoneAuthProvider.credential(
        verificationId: 'id',
        smsCode: '123456',
      );

     
      capturedVerificationCompleted(fakeCredential);
      await Future.delayed(Duration.zero);
      expect(linked, mockCredential);
    });
  });

  test('calls onVerificationFailed when Firebase verification fails', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  late void Function(FirebaseAuthException) capturedFailed;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    capturedFailed = invocation.namedArguments[#verificationFailed];
  });

  FirebaseAuthException? error;

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (e) => error = e,
  );

  final fakeError = FirebaseAuthException(code: 'test-error');

  capturedFailed(fakeError);

  expect(error, fakeError);
});

test('stores verificationId on auto retrieval timeout', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  late void Function(String) capturedTimeout;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    capturedTimeout =
        invocation.namedArguments[#codeAutoRetrievalTimeout];
  });

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  capturedTimeout('timeoutId');

  expect(service.linkVerificationId, 'timeoutId');
});

test('auto link handles FirebaseAuthException', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockUser.linkWithCredential(any()))
      .thenThrow(FirebaseAuthException(code: 'link-failed'));

  late void Function(PhoneAuthCredential) verificationCompleted;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    verificationCompleted =
        invocation.namedArguments[#verificationCompleted];
  });

  FirebaseAuthException? error;

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (e) => error = e,
  );

  final credential = PhoneAuthProvider.credential(
    verificationId: 'id',
    smsCode: '123456',
  );

  verificationCompleted(credential);
  await Future.delayed(Duration.zero);

  expect(error, isNotNull);
  expect(error!.code, 'link-failed');
});

test('auto link handles generic exception', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockUser.linkWithCredential(any()))
      .thenThrow(Exception('unknown'));

  late void Function(PhoneAuthCredential) verificationCompleted;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    verificationCompleted =
        invocation.namedArguments[#verificationCompleted];
  });

  FirebaseAuthException? error;

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (e) => error = e,
  );

  final credential = PhoneAuthProvider.credential(
    verificationId: 'id',
    smsCode: '123456',
  );

  verificationCompleted(credential);
  await Future.delayed(Duration.zero);

  expect(error, isNotNull);
  expect(error!.code, 'auto-verification-failed');
});

test('auto link fails when currentUser is null', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  late void Function(PhoneAuthCredential) verificationCompleted;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    verificationCompleted =
        invocation.namedArguments[#verificationCompleted];
  });

  FirebaseAuthException? error;

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (e) => error = e,
  );

  //  هون بنغير الحالة لمحاكاة انتهاء session
  when(() => mockAuth.currentUser).thenReturn(null);

  final credential = PhoneAuthProvider.credential(
    verificationId: 'id',
    smsCode: '123456',
  );

  verificationCompleted(credential);
  await Future.delayed(Duration.zero);

  expect(error, isNotNull);
  expect(error!.code, 'no-current-user');
});

test('uses resend token on subsequent OTP requests', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  int? passedToken;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    passedToken =
        invocation.namedArguments[#forceResendingToken] as int?;
    final codeSent =
        invocation.namedArguments[#codeSent] as void Function(String, int?);

    // أول إرسال يعطي توكن
    codeSent('id1', 111);
  });

  // أول إرسال (لا يوجد توكن بعد)
  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  expect(passedToken, null);

  // الإرسال الثاني يجب أن يمرر التوكن السابق (111)
  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  expect(passedToken, 111);
});

test('updates resend token after codeSent', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  int? latestToken;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    final codeSent =
        invocation.namedArguments[#codeSent] as void Function(String, int?);

    // أعطِ توكن جديد
    codeSent('id', 555);
    latestToken = 555;
  });

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  // تأكيد غير مباشر: الإرسال التالي يمرر نفس التوكن
  int? passedToken;
  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    passedToken =
        invocation.namedArguments[#forceResendingToken] as int?;
  });

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  expect(latestToken, 555);
  expect(passedToken, 555);
});

test('clears verification state after successful link', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  final mockCredential = MockUserCredential();

  when(() => mockUser.linkWithCredential(any()))
      .thenAnswer((_) async => mockCredential);

  late void Function(String, int?) codeSent;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    codeSent =
        invocation.namedArguments[#codeSent] as void Function(String, int?);
  });

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  codeSent('id', 999);

  final result =
      await service.verifyOtpAndLink(smsCode: '123456');

  expect(result, mockCredential);
  expect(service.linkVerificationId, null);
  expect(service.hasPendingLinkVerification, false);
});

test('verifyPhoneNumber is called exactly once per request', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((_) async {});

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  verify(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).called(1);
});

test('verifyPhoneNumber is called exactly once per request', () async {
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((_) async {});

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  verify(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).called(1);
});

test('throws when currentUser is null during verifyOtpAndLink', () async {
  // خلي المستخدم موجود بالبداية عشان نمرر codeSent
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  late void Function(String, int?) codeSent;

  when(() => mockAuth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        timeout: any(named: 'timeout'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout:
            any(named: 'codeAutoRetrievalTimeout'),
      )).thenAnswer((invocation) async {
    codeSent =
        invocation.namedArguments[#codeSent] as void Function(String, int?);
  });

  await service.sendSmsOtpToLinkCurrentUser(
    phoneNumber: '+962791234567',
    onCodeSent: () {},
    onVerificationFailed: (_) {},
  );

  // نحط verificationId
  codeSent('testId', null);

  //  session بينتهي هون
  when(() => mockAuth.currentUser).thenReturn(null);

  expect(
    () => service.verifyOtpAndLink(smsCode: '123456'),
    throwsA(
      isA<FirebaseAuthException>()
          .having((e) => e.code, 'code', 'no-current-user'),
    ),
  );
});
}