import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bloodbank_donors/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String createdRequestId;

  setUpAll(() async {
    await Firebase.initializeApp(options:DefaultFirebaseOptions.currentPlatform,);

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'ehdaa.hamdan@gmail.com',
      password: '123456',
    );
  });

  testWidgets('addRequest integration' ,(tester) async {

      createdRequestId ='integration_${DateTime.now().millisecondsSinceEpoch}';

      final result = await FirebaseFunctions.instance
        .httpsCallable('addRequest')
        .call({
        'requestId': createdRequestId,
        'bloodBankName': 'Test Hospital',
        'bloodType': 'A+',
        'units': 2,
        'hospitalLocation': 'Amman',
        'isUrgent': true,
        'details':'Request created from integration test',
      }).timeout(const Duration(seconds: 20),);

      expect(result.data, isA<Map>());
      expect(result.data['ok'], true);
    },
  );

  testWidgets('getRequests integration',(tester) async {

      final result = await FirebaseFunctions.instance
        .httpsCallable('getRequests')
        .call({
        'limit': 20,
      }).timeout(const Duration(seconds: 20),);

      expect(result.data['requests'], isA<List>(), );

      final requests = (result.data['requests'] as List)
        .map((e) => Map<String, dynamic>.from(e),).toList();

      expect(requests.any((r) => r['id'] == createdRequestId,), true,);
    },
  );

  testWidgets('deleteRequest positive integration',(tester) async {

      final result =await FirebaseFunctions.instance
        .httpsCallable('deleteRequest')
        .call({
        'requestId': createdRequestId,
      }).timeout(const Duration(seconds: 20), );

      expect(result.data['ok'], true);
    },
  );

  testWidgets('verify request deleted',(tester) async {

      final result = await FirebaseFunctions.instance
       .httpsCallable('getRequests')
       .call({'limit': 20,
      }).timeout(const Duration(seconds: 20),);

      final requests = List<Map<String, dynamic>>.from( result.data['requests'], );

      expect(requests.any((r) => r['id'] == createdRequestId,), false,);
    },
  );

  testWidgets('deleteRequest negative integration',(tester) async {

      try {
        await FirebaseFunctions.instance
          .httpsCallable('deleteRequest')
          .call({
          'requestId':'non_existing_request_id',
        });

        fail('Expected function to throw',);
      } catch (e) {
        expect(e, isNotNull);
      }
    },
  );
}