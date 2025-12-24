import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloodbank_donors/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeDb;
  late AuthService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeDb = FakeFirebaseFirestore();
    service = AuthService(auth: mockAuth, db: fakeDb);
  });


            /// test cases///


        ///signUpDonor stores user data in firestore///

test('signUpDonor stores user data in firestore', () async {
  final mockUser = MockUser();
  when(() => mockUser.uid).thenReturn("abc123");
  when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});

  final mockCred = MockUserCredential();
  when(() => mockCred.user).thenReturn(mockUser);

  when(() => mockAuth.createUserWithEmailAndPassword(
    email: any(named: 'email'),
    password: any(named: 'password'),
  )).thenAnswer((_) async => mockCred);

  await service.signUpDonor(
    fullName: "Test Donor",
    email: "test@test.com",
    password: "123456",
    bloodType: "A+",
    location: "Amman",
  );

  final doc = await fakeDb.collection('users').doc("abc123").get();

  expect(doc.exists, true);
  expect(doc['role'], 'donor');
  expect(doc['bloodType'], 'A+');
});



        ///signUpBloodBank stores hospital correctly///

test('signUpBloodBank stores hospital correctly', () async {
  final user = MockUser();
  when(() => user.uid).thenReturn("bank001");
  when(() => user.sendEmailVerification()).thenAnswer((_) async {});

  final cred = MockUserCredential();
  when(() => cred.user).thenReturn(user);

  when(() => mockAuth.createUserWithEmailAndPassword(
    email: any(named: 'email'),
    password: any(named: 'password'),
  )).thenAnswer((_) async => cred);

  await service.signUpBloodBank(
    bloodBankName: "Irbid Bank",
    email: "bank@test.com",
    password: "123456",
    location: "Irbid",
  );

  final doc = await fakeDb.collection("users").doc("bank001").get();

  expect(doc.exists, true);
  expect(doc["role"], "hospital");
  expect(doc["bloodBankName"], "Irbid Bank");
});

        ///login///

test('login calls firebase auth login', () async {
  when(() => mockAuth.signInWithEmailAndPassword(
    email: any(named: 'email'),
    password: any(named: 'password'),
  )).thenAnswer((_) async => MockUserCredential());

  await service.login(email: "a@a.com", password: "123456");

  verify(() => mockAuth.signInWithEmailAndPassword(
    email: "a@a.com",
    password: "123456",
  )).called(1);
});

        /// logout///

test('logout calls firebase signOut', () async {
  when(() => mockAuth.signOut()).thenAnswer((_) async {});

  await service.logout();

  verify(() => mockAuth.signOut()).called(1);
});

        ///getUserRole///
test('getUserRole returns correct role', () async {
  await fakeDb.collection('users').doc('u1').set({
    "role": "donor"
  });

  final role = await service.getUserRole("u1");

  expect(role, "donor");
});


        ///getUserData///

test('getUserData returns user object when exists', () async {
  await fakeDb.collection('users').doc('u22').set({
    "role": "donor",
    "fullName": "Layan",
    "email": "l@test.com"
  });

  final data = await service.getUserData("u22");

  expect(data, isNotNull);
  expect(data!.email, "l@test.com");
});

               

}
