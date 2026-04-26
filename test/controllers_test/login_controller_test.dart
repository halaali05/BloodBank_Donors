import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/controllers/login_controller.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/models/login_models.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;

// ------------------ Mocks ------------------
class MockAuthService extends Mock implements AuthService {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthService mockAuth;
  late LoginController controller;

  setUp(() {
    mockAuth = MockAuthService();
    controller = LoginController(authService: mockAuth);
  });

  group('validateInput', () {
    test('valid input returns true', () {
      expect(controller.validateInput('a@test.com', '123456'), true);
    });

    test('empty email returns false', () {
      expect(controller.validateInput('', '123456'), false);
    });

    test('empty password returns false', () {
      expect(controller.validateInput('a@test.com', ''), false);
    });

    test('email with spaces is accepted', () {
      expect(controller.validateInput('   a@test.com   ', '123456'), true);
    });
  });


  group('login ', () {
    test('email not verified', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => false);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.emailNotVerified);
    });

    test('currentUser is null', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.userNotFound);
    });

    test('profile not ready', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u3');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u3')).thenAnswer((_) async => null);
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.profileNotReady);
    });
  
    test('donor login success', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u1');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u1'))
          .thenAnswer((_) async => models.User(
                uid: 'u1',
                email: 'a@test.com',
                role: models.UserRole.donor,
              ));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.navigationRoute, isNotNull);
    });

    test('hospital login success', () async {
      final user = MockUser();

      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('u2');

      when(() => mockAuth.completeProfileAfterVerification())
          .thenAnswer((_) async => {});
      when(() => mockAuth.getUserData('u2'))
          .thenAnswer((_) async => models.User(
                uid: 'u2',
                email: 'h@test.com',
                role: models.UserRole.hospital,
                bloodBankName: 'Central Bank',
                location: 'Amman',
              ));

      final r = await controller.login(
        email: 'h@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.navigationRoute, isNotNull);
    });
  
    test('wrong-password → authException', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      final r = await controller.login(
        email: 'a@test.com',
        password: 'wrong',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
    });

    test('invalid-email → title mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      final r = await controller.login(
        email: 'bad',
        password: '123',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
      expect(r.errorTitle, 'Invalid email address');
    });

    test('user-disabled → title mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'user-disabled'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.authException);
      expect(r.errorTitle, 'Account disabled');
    });
  
    test('network error → genericError with Connection title', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('network timeout'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.genericError);
      expect(r.errorTitle, isNotNull);
    });

    test('unknown error → genericError', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('boom'));

      final r = await controller.login(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorType, LoginErrorType.genericError);
    });
  });


  group('resendVerification', () {
    test('success path', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenAnswer((_) async {});
      when(() => mockAuth.resendEmailVerification())
          .thenAnswer((_) async {});
      when(() => mockAuth.logout()).thenAnswer((_) async {});

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, true);
      expect(r.message, isNotNull);
    });

    test('FirebaseAuthException mapped', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorTitle, isNotNull);
    });

    test('generic exception', () async {
      when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password')))
          .thenThrow(Exception('boom'));

      final r = await controller.resendVerification(
        email: 'a@test.com',
        password: '123456',
      );

      expect(r.success, false);
      expect(r.errorTitle, 'Error');
    });

    test('resendVerification fails in resendEmailVerification', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.resendEmailVerification())
      .thenThrow(Exception());

  final r = await controller.resendVerification(
    email: 'a@test.com',
    password: '123',
  );

  expect(r.success, false);
});

    test('resendVerification fails in logout', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.resendEmailVerification())
      .thenAnswer((_) async {});

  when(() => mockAuth.logout()).thenThrow(Exception());

  final r = await controller.resendVerification(
    email: 'a@test.com',
    password: '123',
  );

  expect(r.success, false);
});

 
  });


group('Exception', () {
test('Exception prefix parsing - network', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(Exception('Exception: network failure'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorType, LoginErrorType.genericError);
  expect(r.errorTitle, 'Connection error');
});

test('Exception prefix parsing - permission', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(Exception('Exception: permission denied'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Permission denied');
});


test('Exception prefix parsing - profile', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(Exception('Exception: profile not found'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Profile not found');
});


test('Exception prefix parsing - default branch', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(Exception('Exception: something weird'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Login error');
});

test('profileCompleteFuture handles exception silently', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u1');

  // ✅ FIX
  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) => Future.error(Exception()));

  when(() => mockAuth.getUserData('u1')).thenAnswer((_) async {
    return models.User(
      uid: 'u1',
      email: 'a@test.com',
      role: models.UserRole.donor,
    );
  });

  final r = await controller.login(email: 'a', password: '1');

  expect(r.success, true);
});

});

test('hospital fallback values for name and location', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u2');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) async => {});

  when(() => mockAuth.getUserData('u2')).thenAnswer((_) async {
    return models.User(
      uid: 'u2',
      email: 'h@test.com',
      role: models.UserRole.hospital,
      bloodBankName: null, // fallback
      location: null, // fallback
    );
  });

  final r = await controller.login(email: 'h', password: '1');

  expect(r.success, true);
});

test('email only spaces returns false', () {
  expect(controller.validateInput('   ', '123'), false);
});

test('isEmailVerified throws → genericError', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified())
      .thenThrow(Exception('network'));

  final r = await controller.login(email: 'a', password: '1');

  expect(r.success, false);
  expect(r.errorType, LoginErrorType.genericError);
});

test('unknown firebase error → default mapping', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'some-random-code'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Login failed');
});

test('too-many-requests → mapped title', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'too-many-requests'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Too many attempts');
});

test('operation-not-allowed → mapped title', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Login disabled');
});
test('profileCompleteFuture handles failure (no timeout needed)', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u1');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) => Future.error(Exception()));

  when(() => mockAuth.getUserData('u1')).thenAnswer((_) async {
    return models.User(
      uid: 'u1',
      email: 'a@test.com',
      role: models.UserRole.donor,
    );
  });

  final r = await controller.login(email: 'a', password: '1');

  expect(r.success, true);
});
test('network-request-failed → mapped title', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Network error');
});

test('invalid-credential → mapped title', () async {
  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.errorTitle, 'Invalid credentials');
});

group('getUserData', () {
test('getUserData fails twice → profileNotReady', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u9');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) async => {});

  when(() => mockAuth.getUserData('u9'))
      .thenAnswer((_) async => null);

  when(() => mockAuth.logout()).thenAnswer((_) async {});

  final r = await controller.login(email: 'a', password: 'b');

  expect(r.success, false);
  expect(r.errorType, LoginErrorType.profileNotReady);
});

test('getUserData succeeds on retry', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u5');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) async => {});

  int callCount = 0;
  when(() => mockAuth.getUserData('u5')).thenAnswer((_) async {
    callCount++;
    if (callCount == 1) return null;
    return models.User(
      uid: 'u5',
      email: 'a@test.com',
      role: models.UserRole.donor,
    );
  });

  final r = await controller.login(
    email: 'a@test.com',
    password: '123',
  );

  expect(r.success, true);
});
test('getUserData succeeds on retry (null first)', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u7');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) async => {});

  int calls = 0;
  when(() => mockAuth.getUserData('u7')).thenAnswer((_) async {
    calls++;
    if (calls == 1) return null; // ✅ بدل throw
    return models.User(
      uid: 'u7',
      email: 'a@test.com',
      role: models.UserRole.donor,
    );
  });

  final r = await controller.login(email: 'a', password: '1');

  expect(r.success, true);
});
test('getUserData throws twice → genericError', () async {
  final user = MockUser();

  when(() => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async {});

  when(() => mockAuth.isEmailVerified()).thenAnswer((_) async => true);
  when(() => mockAuth.currentUser).thenReturn(user);
  when(() => user.uid).thenReturn('u8');

  when(() => mockAuth.completeProfileAfterVerification())
      .thenAnswer((_) async => {});

  when(() => mockAuth.getUserData('u8'))
      .thenThrow(Exception('db down'));

  final r = await controller.login(email: 'a', password: '1');

  expect(r.success, false);
  expect(r.errorType, LoginErrorType.genericError);
});
});

}
