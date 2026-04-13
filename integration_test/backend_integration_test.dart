import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:bloodbank_donors/firebase_options.dart';


    ///addRequest + 
    ///getRequests + 
    ///getDonors + 
    ///markNotificationsAsRead +
    /// deleteRequest
     
    
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  });

  testWidgets('addRequest integration test', (tester) async {
    final result = await FirebaseFunctions.instance.httpsCallable('addRequest').call({
      'requestId': 'integration_test_req_001',
      'bloodBankName': 'Test Hospital',
      'bloodType': 'A+',
      'units': 2,
      'hospitalLocation': 'Amman',
      'isUrgent': true,
      'details': 'Request created from integration test',
    });

    expect(result.data['ok'], true);
  });

testWidgets('getRequests integration test', (tester) async {
  final result = await FirebaseFunctions.instance.httpsCallable('getRequests').call({
    'limit': 5,
  });

  expect(result.data, isNotNull);
  expect(result.data['requests'], isA<List>());
});

testWidgets('getDonors integration test', (tester) async {
  final result = await FirebaseFunctions.instance.httpsCallable('getDonors').call({
    'bloodType': 'A+',
  });

  expect(result.data['ok'], true);
  expect(result.data['donors'], isA<List>());
});

testWidgets('markNotificationsAsRead integration test', (tester) async {
  final result = await FirebaseFunctions.instance.httpsCallable('markNotificationsAsRead').call();

  expect(result.data['ok'], true);
});

testWidgets('deleteRequest --negative-- integration test', (tester) async {
  try {
    await FirebaseFunctions.instance.httpsCallable('deleteRequest').call({
      'requestId': 'non_existing_request_id',
    });

    fail('Expected function to throw an error');
  } catch (e) {
    expect(e, isNotNull);
  }
});

}