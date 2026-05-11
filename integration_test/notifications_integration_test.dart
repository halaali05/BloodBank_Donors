import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bloodbank_donors/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'ehdaa.hamdan@gmail.com',
      password: '123456',
    );
  });

  testWidgets('markNotificationsAsRead integration',(tester) async {

      final result = await FirebaseFunctions.instance
              .httpsCallable('markNotificationsAsRead')
              .call()
              .timeout(const Duration(seconds: 20),);

      expect(result.data['ok'], true);
    },
  );
}