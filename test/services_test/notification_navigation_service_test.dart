import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core; 
import 'package:firebase_core_platform_interface/test.dart';
import 'package:bloodbank_donors/models/user_model.dart' as models;
import 'package:bloodbank_donors/services/auth_service.dart';
import 'package:bloodbank_donors/services/notification_navigation_service.dart';

// ================= MOCKS =================

class MockFirebaseAuth extends Mock
    implements firebase.FirebaseAuth {}

class MockFirebaseUser extends Mock implements firebase.User {}

class MockAuthService extends Mock implements AuthService {}

// ================= TESTS =================

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();

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
    service.authServiceFactory = () => mockAuthService;
  });

   setUpAll(() async {
    await Firebase.initializeApp();
 
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

    // ================= NOTIFICATION TYPES =================

  group('notification type handling', () {

    Future<void> mockAuthenticatedDonor() async {
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
        () => mockAuthService.getUserData(any()),
      ).thenAnswer(
        (_) async => models.User(
          uid: 'u1',
          email: 'donor@test.com',
          role: models.UserRole.donor,
        ),
      );
    }

    Future<void> mockAuthenticatedHospital() async {
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
        () => mockAuthService.getUserData(any()),
      ).thenAnswer(
        (_) async => models.User(
          uid: 'u1',
          email: 'hospital@test.com',
          role: models.UserRole.hospital,
          bloodBankName: 'Bank',
          location: 'Amman',
        ),
      );
    }

   testWidgets('handles account_approved for hospital', (tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedHospital();

    service.openFromData({
      'type': 'account_approved',
    });

    await tester.pump();
    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);
   
    testWidgets('handles account_rejected notification',(tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'account_rejected',
        });

        await tester.pumpAndSettle();

        expect(find.text('Registration Not Approved'),
            findsOneWidget);
      },
    );

    testWidgets('handles chat notification', (tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'chat',
          'requestId': 'req1',
          'senderId': 'sender1',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles appointment_scheduled for donor',(tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'appointment_scheduled',
          'requestId': 'req1',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles medical_report_saved for donor', (tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'medical_report_saved',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles request notification',(tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'request',
          'requestId': 'req123',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

    testWidgets('handles unknown notification type for donor', (tester) async {
        await pumpTestApp(tester);

        await mockAuthenticatedDonor();

        service.openFromData({
          'type': 'unknown_type',
        });

        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );

  
    testWidgets('handles non notification tap navigation', (tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedDonor();

    service.openFromData(
      {
        'type': 'chat',
        'requestId': '123',
      },
      fromNotificationTap: false,
    );

    await tester.pump();
    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);

    testWidgets('handles empty requestId', (tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedDonor();

    service.openFromData({
      'type': 'chat',
      'requestId': '',
    });

    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);

         await tester.pump(
      const Duration(seconds: 2),
    );

    // dispose tree
    await tester.pumpWidget(
      const SizedBox(),
    );
  },
);

    testWidgets('handles unknown notification for hospital',(tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedHospital();

    service.openFromData({
      'type': 'unknown',
    });

    await tester.pump();
    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);

    await tester.pump(
      const Duration(seconds: 2),
    );

    await tester.pumpWidget(
      const SizedBox(),
    );
  },
);

    testWidgets('handles authStateChanges exception', (tester) async {
    await pumpTestApp(tester);

    when(() => mockAuth.currentUser)
        .thenReturn(null);

    when(
      () => mockAuth.authStateChanges(),
    ).thenThrow(Exception());

    service.openFromData({
      'type': 'request',
    });

    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);

    testWidgets('handles malformed payload map',(tester) async {
    await pumpTestApp(tester);

    when(() => mockAuth.currentUser)
        .thenReturn(null);

    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer(
      (_) => const Stream.empty(),
    );

    service.openFromPayloadJson(
      '{"bad_json":true}',
    );

    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);

testWidgets('handles donor fallback navigation',(tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedDonor();

    service.openFromData({
      'type': 'unknown',
    });

    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 200),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);

     await tester.pump(
      const Duration(seconds: 2),
    );

    await tester.pumpWidget(
      const SizedBox(),
    );
  },
);

testWidgets('handles hospital with null fields',(tester) async {
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
      () => mockAuthService.getUserData(any()),
    ).thenAnswer(
      (_) async => models.User(
        uid: 'u1',
        email: 'hospital@test.com',
        role: models.UserRole.hospital,
      ),
    );

    service.openFromData({
      'type': 'unknown',
    });

    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 200),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);

      await tester.pump(
      const Duration(seconds: 2),
    );

    await tester.pumpWidget(
      const SizedBox(),
    );
  },
);

testWidgets('handles malformed notification data', (tester) async {
    await pumpTestApp(tester);

    await mockAuthenticatedDonor();

    service.openFromData({
      'type': null,
      'requestId': null,
      'senderId': null,
      'recipientId': null,
    });

    await tester.pump(
      const Duration(milliseconds: 300),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);

      await tester.pump(
      const Duration(seconds: 2),
    );  

    await tester.pumpWidget(
      const SizedBox(),
    );
  },
);

testWidgets('handles invalid token after authStateChanges', (tester) async {
    await pumpTestApp(tester);

    when(() => mockAuth.currentUser)
        .thenReturn(null);

    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer(
      (_) => Stream.value(mockUser),
    );

    when(
      () => mockUser.getIdToken(),
    ).thenThrow(Exception());

    service.openFromData({
      'type': 'request',
    });

    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);

testWidgets('handles json list payload',(tester) async {
    await pumpTestApp(tester);

    when(() => mockAuth.currentUser)
        .thenReturn(null);

    when(
      () => mockAuth.authStateChanges(),
    ).thenAnswer(
      (_) => const Stream.empty(),
    );

    service.openFromPayloadJson(
      '["123"]',
    );

    await tester.pump(
      const Duration(seconds: 1),
    );

    expect(find.byType(MaterialApp),
        findsOneWidget);
  },
);

  });


 }