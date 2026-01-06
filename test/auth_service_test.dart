import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;

/// ---------- MOCKS ----------
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockCloudFunctionsService mockCloud;
  late AuthService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockCloud = MockCloudFunctionsService();

    service = AuthService(auth: mockAuth, cloudFunctions: mockCloud,);

  });

  /// --------------------------------------------------
  /// signUpDonor
  /// --------------------------------------------------
  test('signUpDonor creates user, calls cloud function, sends verification',
      () async {
    final mockUser = MockUser();
    final mockCred = MockUserCredential();

    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.reload()).thenAnswer((_) async {});
    when(() => mockUser.getIdToken(true)).thenAnswer((_) async => 'token');
    when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
    when(() => mockCred.user).thenReturn(mockUser);

    when(() => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => mockCred);

    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockCloud.createPendingProfile(
          role: 'donor',
          fullName: any(named: 'fullName'),
          bloodType: any(named: 'bloodType'),
          location: any(named: 'location'),
          medicalFileUrl: any(named: 'medicalFileUrl'),
        )).thenAnswer((_) async {
      return {
        'emailVerified': false,
        'message': 'Verification email sent',
      };
    });

    final result = await service.signUpDonor(
      fullName: 'Donor',
      email: 'donor@test.com',
      password: '123456',
      bloodType: 'A+',
      location: 'Amman',
    );

    expect(result['emailVerified'], false);
    expect(result['message'], 'Verification email sent');

    verify(() => mockCloud.createPendingProfile(
          role: 'donor',
          fullName: 'Donor',
          bloodType: 'A+',
          location: 'Amman',
          medicalFileUrl: null,
        )).called(1);

    verify(() => mockUser.sendEmailVerification()).called(1);
  });

  /// --------------------------------------------------
  /// signUpBloodBank
  /// --------------------------------------------------
  test(
      'signUpBloodBank creates hospital user and sends verification email',
      () async {
    final mockUser = MockUser();
    final mockCred = MockUserCredential();

    when(() => mockUser.uid).thenReturn('bank1');
    when(() => mockUser.reload()).thenAnswer((_) async {});
    when(() => mockUser.getIdToken(true)).thenAnswer((_) async => 'token');
    when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
    when(() => mockCred.user).thenReturn(mockUser);
    when(() => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => mockCred);

    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockCloud.createPendingProfile(
          role: 'hospital',
          bloodBankName: any(named: 'bloodBankName'),
          location: any(named: 'location'),
        )).thenAnswer((_) async {
      return {
        'emailVerified': false,
        'message': 'Verification email sent',
      };
    });

    final result = await service.signUpBloodBank(
      bloodBankName: 'Irbid Hospital',
      email: 'bank@test.com',
      password: '123456',
      location: 'Irbid',
    );

    expect(result['emailVerified'], false);
    verify(() => mockUser.sendEmailVerification()).called(1);
  });

  /// --------------------------------------------------
  /// login
  /// --------------------------------------------------
  test('login calls FirebaseAuth signIn', () async {
    when(() => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => MockUserCredential());

    await service.login(email: 'a@a.com', password: '123456');

    verify(() => mockAuth.signInWithEmailAndPassword(
          email: 'a@a.com',
          password: '123456',
        )).called(1);
  });

  /// --------------------------------------------------
  /// logout
  /// --------------------------------------------------
  test('logout calls FirebaseAuth signOut', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    await service.logout();

    verify(() => mockAuth.signOut()).called(1);
  });

  /// --------------------------------------------------
  /// getUserRole
  /// --------------------------------------------------
  test('getUserRole returns role from cloud functions', () async {
    when(() => mockCloud.getUserRole(uid: any(named: 'uid')))
        .thenAnswer((_) async => 'donor');

    final role = await service.getUserRole('uid1');

    expect(role, 'donor');
  });

  /// --------------------------------------------------
  /// getUserData
  /// --------------------------------------------------
  test('getUserData returns User model when data exists', () async {
    when(() => mockCloud.getUserData(uid: any(named: 'uid')))
        .thenAnswer((_) async {
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

  /// --------------------------------------------------
  /// resendEmailVerification
  /// --------------------------------------------------
  test('resendEmailVerification sends email if not verified', () async {
    final mockUser = MockUser();

    when(() => mockUser.emailVerified).thenReturn(false);
    when(() => mockUser.sendEmailVerification())
        .thenAnswer((_) async {});
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    await service.resendEmailVerification();

    verify(() => mockUser.sendEmailVerification()).called(1);
  });

  /// --------------------------------------------------
  /// completeProfileAfterVerification
  /// --------------------------------------------------
  test('completeProfileAfterVerification calls cloud function if verified',
      () async {
    final mockUser = MockUser();

    when(() => mockUser.emailVerified).thenReturn(true);
    when(() => mockUser.reload()).thenAnswer((_) async {});
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockCloud.completeProfileAfterVerification())
        .thenAnswer((_) async => {'success': true});

    final result = await service.completeProfileAfterVerification();

    expect(result['success'], true);
  });
}
