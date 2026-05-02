import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;

/// ---------- MOCKS ----------
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUserInfo extends Mock implements UserInfo {}

class MockUser extends Mock implements User {}

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockCloudFunctionsService mockCloud;
  late AuthService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockCloud = MockCloudFunctionsService();

    service = AuthService(auth: mockAuth, cloudFunctions: mockCloud);
  });

  /// signUpDonor
group('signUpDonor', () {
  test('signUpDonor creates user, calls cloud function, sends verification',
    () async {
      final mockUser = MockUser();
      final mockCred = MockUserCredential();

      when(() => mockUser.uid).thenReturn('uid123');
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockUser.getIdToken(true)).thenAnswer((_) async => 'token');
      when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
      when(() => mockCred.user).thenReturn(mockUser);

      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockCred);

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockCloud.createPendingProfile(
          role: 'donor',
          fullName: any(named: 'fullName'),
          location: any(named: 'location'),
          gender: any(named: 'gender'),
          phoneNumber: any(named: 'phoneNumber'),
        ),
      ).thenAnswer((_) async {
        return {'emailVerified': false, 'message': 'Verification email sent'};
      });

      final result = await service.signUpDonor(
        fullName: 'Donor',
        email: 'donor@test.com',
        password: '123456',
        location: 'Amman',
        gender: 'male',
        phoneNumber: '+962791234567',
      );

      expect(result['emailVerified'], false);
      expect(result['message'], 'Verification email sent');

      verify(
        () => mockCloud.createPendingProfile(
          role: 'donor',
          fullName: 'Donor',
          location: 'Amman',
          gender: 'male',
          phoneNumber: '+962791234567',
        ),
      ).called(1);

      verify(() => mockUser.sendEmailVerification()).called(1);
    },
  );

  test('signUpDonor handles email verification failure gracefully', () async {
  final mockUser = MockUser();
  final mockCred = MockUserCredential();

  when(() => mockCred.user).thenReturn(mockUser);
  when(() => mockUser.sendEmailVerification())
      .thenThrow(Exception('email fail'));

  when(() => mockAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => mockCred);

  when(() => mockCloud.createPendingProfile(
        role: any(named: 'role'),
        fullName: any(named: 'fullName'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
      )).thenAnswer((_) async => {'emailVerified': false});

  final result = await service.signUpDonor(
    fullName: 'Test',
    email: 't@test.com',
    password: '123456',
    location: 'Amman',
    gender: 'male',
    phoneNumber: '079',
  );

  expect(result['message'], contains('Account created'));
});
  
  test('signUpDonor trims email before sending', () async {
  final mockUser = MockUser();
  final mockCred = MockUserCredential();

  when(() => mockCred.user).thenReturn(mockUser);
  when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});

  when(() => mockAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((invocation) async {
    final email = invocation.namedArguments[#email];
    expect(email, 'trim@test.com'); // ASSERT TRIM
    return mockCred;
  });

  when(() => mockCloud.createPendingProfile(
        role: any(named: 'role'),
        fullName: any(named: 'fullName'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
      )).thenAnswer((_) async => {});

  await service.signUpDonor(
    fullName: 'Test',
    email: '  trim@test.com  ',
    password: '123456',
    location: 'Amman',
    gender: 'male',
    phoneNumber: '079',
  );
});

test('signUpDonor rethrows when cloud function fails', () async {
  final mockUser = MockUser();
  final mockCred = MockUserCredential();

  when(() => mockCred.user).thenReturn(mockUser);

  when(() => mockAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => mockCred);

  when(() => mockCloud.createPendingProfile(
        role: any(named: 'role'),
        fullName: any(named: 'fullName'),
        location: any(named: 'location'),
        gender: any(named: 'gender'),
        phoneNumber: any(named: 'phoneNumber'),
      )).thenThrow(Exception('cloud error'));

  expect(
    () => service.signUpDonor(
      fullName: 'Test',
      email: 'test@test.com',
      password: '123456',
      location: 'Amman',
      gender: 'male',
      phoneNumber: '079',
    ),
    throwsException,
  );
});
  });
 
   /// signUpBloodBank
group('signUpBloodBank', () {
  test('signUpBloodBank creates hospital user and sends verification email',
    () async {
      final mockUser = MockUser();
      final mockCred = MockUserCredential();

      when(() => mockUser.uid).thenReturn('bank1');
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockUser.getIdToken(true)).thenAnswer((_) async => 'token');
      when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
      when(() => mockCred.user).thenReturn(mockUser);
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockCred);

      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockCloud.createPendingProfile(
          role: 'hospital',
          bloodBankName: any(named: 'bloodBankName'),
          location: any(named: 'location'),
        ),
      ).thenAnswer((_) async {
        return {'emailVerified': false, 'message': 'Verification email sent'};
      });

      final result = await service.signUpBloodBank(
        bloodBankName: 'Irbid Hospital',
        email: 'bank@test.com',
        password: '123456',
        location: 'Irbid',
      );

      expect(result['emailVerified'], false);
      verify(() => mockUser.sendEmailVerification()).called(1);
    },
  );

  test('signUpBloodBank handles email verification failure', () async {
  final mockUser = MockUser();
  final mockCred = MockUserCredential();

  when(() => mockCred.user).thenReturn(mockUser);

  when(() => mockUser.sendEmailVerification())
      .thenThrow(Exception('email fail'));

  when(() => mockAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => mockCred);

  when(() => mockCloud.createPendingProfile(
        role: any(named: 'role'),
        bloodBankName: any(named: 'bloodBankName'),
        location: any(named: 'location'),
      )).thenAnswer((_) async => {'emailVerified': false});

  final result = await service.signUpBloodBank(
    bloodBankName: 'Bank',
    email: 'bank@test.com',
    password: '123',
    location: 'Amman',
  );

  expect(result['message'], contains('Account created'));
});
  });
 
  /// login
 
 group('login', () {
    test('login calls FirebaseAuth signIn', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => MockUserCredential());

    await service.login(email: 'a@a.com', password: '123456');

    verify(
      () => mockAuth.signInWithEmailAndPassword(
        email: 'a@a.com',
        password: '123456',
      ),
    ).called(1);
  });

 test('login triggers updateLastLoginAt when user exists', () async {
  final mockUser = MockUser();

  when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => MockUserCredential());

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockCloud.updateLastLoginAt())
      .thenAnswer((_) async => {'success': true});

  await service.login(email: 'a@a.com', password: '123');

  verify(() => mockCloud.updateLastLoginAt()).called(1);
});
  
  test('login does not call updateLastLoginAt when user is null', () async {
  when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => MockUserCredential());

  when(() => mockAuth.currentUser).thenReturn(null);

  await service.login(email: 'a@a.com', password: '123');

  verifyNever(() => mockCloud.updateLastLoginAt());
});
  
  
  test('refreshLastLoginTelemetry ignores errors', () async {
  final mockUser = MockUser();

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockCloud.updateLastLoginAt())
      .thenAnswer((_) => Future.error(Exception('fail')));

  // ما لازم يرمي exception
  await service.refreshLastLoginTelemetry();

  verify(() => mockCloud.updateLastLoginAt()).called(1);
});

  test('resolveDonorEmailForPhoneLogin returns email', () async {
  when(() => mockCloud.resolveDonorEmailForPhoneLogin(any()))
      .thenAnswer((_) async => 'test@email.com');

  final result =
      await service.resolveDonorEmailForPhoneLogin('+96279');

  expect(result, 'test@email.com');
});

  });
  /// logout
  test('logout calls FirebaseAuth signOut', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    await service.logout();

    verify(() => mockAuth.signOut()).called(1);
  });

  /// getUserRole
 
  test('getUserRole returns role from cloud functions', () async {
    when(
      () => mockCloud.getUserRole(uid: any(named: 'uid')),
    ).thenAnswer((_) async => 'donor');

    final role = await service.getUserRole('uid1');

    expect(role, 'donor');
  });

  /// getUserData
  
group('getUserData', () {
  test('getUserData returns User model when data exists', () async {
    when(() => mockCloud.getUserData(uid: any(named: 'uid'))).thenAnswer((
      _,
    ) async {
      return {
        'uid': 'u1',
        'email': 'test@test.com',
        'role': 'donor',
        'fullName': 'Test User',
      };
    });

    final user = await service.getUserData('u1');

    expect(user, isNotNull);
    expect(user!.email, 'test@test.com');
    expect(user.role, models.UserRole.donor);
  });

 test('getUserData returns null on exception', () async {
  when(() => mockCloud.getUserData(uid: any(named: 'uid')))
      .thenThrow(Exception());

  final result = await service.getUserData('uid');

  expect(result, null);
});

 test('getUserData returns null when no uid available', () async {
  when(() => mockAuth.currentUser).thenReturn(null);

  when(() => mockCloud.getUserData(uid: any(named: 'uid')))
      .thenAnswer((_) async => {});

  final result = await service.getUserData(null);

  expect(result, null);
});
  
  test('currentUser returns firebase current user', () {
  final mockUser = MockUser();

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  expect(service.currentUser, mockUser);
});
  });
 
   /// resendEmailVerification
 
group('resendEmailVerification', () {
  test('resendEmailVerification sends email if not verified', () async {
    final mockUser = MockUser();

    when(() => mockUser.emailVerified).thenReturn(false);
    when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    await service.resendEmailVerification();

    verify(() => mockUser.sendEmailVerification()).called(1);
  });

  test('resendEmailVerification does nothing if already verified', () async {
  final mockUser = MockUser();

  when(() => mockUser.emailVerified).thenReturn(true);
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  await service.resendEmailVerification();

  verifyNever(() => mockUser.sendEmailVerification());
});
  
   test('resendEmailVerification does nothing when user is null', () async {
  when(() => mockAuth.currentUser).thenReturn(null);

  await service.resendEmailVerification();

  verify(() => mockAuth.currentUser).called(1);
  verifyNoMoreInteractions(mockAuth);
});
 
  test('isEmailVerified returns false when user is null', () async {
  when(() => mockAuth.currentUser).thenReturn(null);

  final result = await service.isEmailVerified();

  expect(result, false);
});

  test('isEmailVerified reloads user', () async {
  final mockUser = MockUser();

  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockUser.emailVerified).thenReturn(true);
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  final result = await service.isEmailVerified();

  expect(result, true);
  verify(() => mockUser.reload()).called(1);
});
  
  
  });
 
  /// completeProfileAfterVerification
 
group('completeProfileAfterVerification', () {
  test('completeProfileAfterVerification calls cloud function if verified',
    () async {
      final mockUser = MockUser();

      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      when(
        () => mockCloud.completeProfileAfterVerification(),
      ).thenAnswer((_) async => {'success': true});

      final result = await service.completeProfileAfterVerification();

      expect(result['success'], true);
    },
  );

  test('completeProfileAfterVerification throws if not verified', () async {
  final mockUser = MockUser();

  when(() => mockUser.emailVerified).thenReturn(false);
  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  expect(
    () => service.completeProfileAfterVerification(),
    throwsException,
  );
});

test('completeProfileAfterVerification returns cloud response', () async {
  final mockUser = MockUser();

  when(() => mockUser.emailVerified).thenReturn(true);
  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockCloud.completeProfileAfterVerification())
      .thenAnswer((_) async => {'done': true});

  final result = await service.completeProfileAfterVerification();

  expect(result['done'], true);
});

test('authStateChanges returns stream from FirebaseAuth', () async {
  final controller = Stream<User?>.fromIterable([null]);

  when(() => mockAuth.authStateChanges()).thenAnswer((_) => controller);

  final stream = service.authStateChanges;

  expect(await stream.first, null);
});
});


group('completeDonorOnboardingWhenReady', () {
test('completeDonorOnboardingWhenReady throws if user null', () async {
  when(() => mockAuth.currentUser).thenReturn(null);

  expect(
    () => service.completeDonorOnboardingWhenReady(),
    throwsA(isA<StateError>()),
  );
});

test('completeDonorOnboardingWhenReady throws if user null after reload', () async {
  final mockUser = MockUser();

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockUser.reload()).thenAnswer((_) async {
    when(() => mockAuth.currentUser).thenReturn(null);
  });

  expect(
    () => service.completeDonorOnboardingWhenReady(),
    throwsA(isA<StateError>()),
  );
});

test('completeDonorOnboardingWhenReady throws if email not verified', () async {
  final mockUser = MockUser();

  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockUser.emailVerified).thenReturn(false);
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  expect(
    () => service.completeDonorOnboardingWhenReady(),
    throwsA(isA<DonorOnboardingIncomplete>()),
  );
});

test('completeDonorOnboardingWhenReady throws if phone not linked', () async {
  final mockUser = MockUser();

  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockUser.emailVerified).thenReturn(true);
  when(() => mockUser.providerData).thenReturn([]);

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  expect(
    () => service.completeDonorOnboardingWhenReady(),
    throwsA(isA<DonorOnboardingIncomplete>()),
  );
});
test('completeDonorOnboardingWhenReady succeeds when all conditions met', () async {
  final mockUser = MockUser();
  final mockProvider = MockUserInfo();

  when(() => mockProvider.providerId)
      .thenReturn(PhoneAuthProvider.PROVIDER_ID);

  when(() => mockUser.reload()).thenAnswer((_) async {});
  when(() => mockUser.emailVerified).thenReturn(true);
  when(() => mockUser.providerData).thenReturn([mockProvider]);

  when(() => mockAuth.currentUser).thenReturn(mockUser);

  when(() => mockCloud.completeProfileAfterVerification())
      .thenAnswer((_) async => {'done': true});

  final result =
      await service.completeDonorOnboardingWhenReady();

  expect(result['done'], true);
});
});



}
