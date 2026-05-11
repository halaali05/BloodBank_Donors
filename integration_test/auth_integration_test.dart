import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bloodbank_donors/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  });

  testWidgets('sign in integration test',(tester) async {

      final credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: 'ehdaa.hamdan@gmail.com',
        password: '123456',
      );
      
        expect(credential.user,isNotNull,);
      expect(credential.user!.uid,isNotEmpty,);
    },
  );

  testWidgets('current user exists', (tester) async {

      final user = FirebaseAuth.instance.currentUser;

      expect(user, isNotNull);
    },
  );
}