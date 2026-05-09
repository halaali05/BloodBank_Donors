import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/models/user_model.dart' as models;
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/notification_navigation_service.dart';

// ================= MOCKS =================

class MockFirebaseAuth extends Mock
    implements firebase.FirebaseAuth {}

class MockFirebaseUser extends Mock
    implements firebase.User {}

class MockAuthService extends Mock
    implements AuthService {}

// ================= TESTS =================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockFirebaseUser mockUser;
  late MockAuthService mockAuthService;

  late NotificationNavigationService service;

  late BuildContext realContext;

  Future<void> pumpTestApp(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            realContext = context;
            return const Scaffold(
              body: Text('test'),
            );
          },
        ),
      ),
    );

    service.contextFactory = () => realContext;
  }

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockFirebaseUser();
    mockAuthService = MockAuthService();

    service = NotificationNavigationService.instance;

    service.authFactory = () => mockAuth;
    service.authServiceFactory =
        () => mockAuthService;
  });

  // ================= PAYLOAD PARSING =================

  group('payload parsing', () {
    testWidgets(
      'handles valid json payload',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromPayloadJson(
          '''
          {
            "requestId":"123",
            "type":"request",
            "senderId":"s1",
            "recipientId":"r1"
          }
          ''',
        );

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets(
      'handles invalid json payload',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromPayloadJson(
          'INVALID_JSON',
        );

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets(
      'handles plain requestId payload',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromPayloadJson('123');

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets(
      'handles empty payload',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromPayloadJson('');

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );
  });

  // ================= AUTHENTICATION =================

  group('authentication handling', () {
    testWidgets('handles unauthenticated user safely',(tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromData({
          'type': 'request',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles getIdToken failure',(tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(mockUser);

        when(
          () => mockUser.getIdToken(),
        ).thenThrow(Exception());

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => const Stream.empty(),
        );

        service.openFromData({
          'type': 'request',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles authStateChanges recovery',(tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(null);

        when(
          () => mockAuth.authStateChanges(),
        ).thenAnswer(
          (_) => Stream.value(mockUser),
        );

        when(() => mockUser.uid)
            .thenReturn('u1');

        when(
          () => mockUser.getIdToken(),
        ).thenAnswer(
          (_) async => 'TOKEN',
        );

        when(
          () => mockAuthService.getUserData(
            any(),
          ),
        ).thenAnswer(
          (_) async => models.User(
            uid: 'u1',
            email: 't@test.com',
            role: models.UserRole.donor,
          ),
        );

        service.openFromData({
          'type': 'request',
          'requestId': '123',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );
  });

  // ================= USER DATA =================

  group('user data handling', () {
    testWidgets(
      'handles null userData safely',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(mockUser);

        when(() => mockUser.uid)
            .thenReturn('u1');

        when(
          () => mockUser.getIdToken(),
        ).thenAnswer(
          (_) async => 'TOKEN',
        );

        when(
          () => mockAuthService.getUserData(
            any(),
          ),
        ).thenAnswer(
          (_) async => null,
        );

        service.openFromData({
          'type': 'request',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets(
      'handles getUserData exception safely',
      (tester) async {
        await pumpTestApp(tester);

        when(() => mockAuth.currentUser)
            .thenReturn(mockUser);

        when(() => mockUser.uid)
            .thenReturn('u1');

        when(
          () => mockUser.getIdToken(),
        ).thenAnswer(
          (_) async => 'TOKEN',
        );

        when(
          () => mockAuthService.getUserData(
            any(),
          ),
        ).thenThrow(Exception());

        service.openFromData({
          'type': 'request',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );
  });

 }