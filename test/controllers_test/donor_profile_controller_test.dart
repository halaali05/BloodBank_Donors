import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/controllers/donor_profile_controller.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ---------------- Mocks ----------------
class MockCloudFunctionsService extends Mock
    implements CloudFunctionsService {}

void main() {
  late DonorProfileController controller;
  late MockCloudFunctionsService mockCloud;

  setUp(() {
    mockCloud = MockCloudFunctionsService();
    controller = DonorProfileController(cloudFunctions: mockCloud);
  });

  // --------------------------------------------------
  // fetchUserProfile
  // --------------------------------------------------

  test('fetchUserProfile returns profile data on success', () async {
    // Arrange
    when(() => mockCloud.getUserData()).thenAnswer((_) async => {
          'uid': 'u1',
          'email': 'test@test.com',
          'fullName': 'Ali',
        });

    // Act
    final result = await controller.fetchUserProfile();

    // Assert
    expect(result['uid'], 'u1');
    expect(result['email'], 'test@test.com');
    expect(result['fullName'], 'Ali');

    verify(() => mockCloud.getUserData()).called(1);
  });

  test('fetchUserProfile throws exception on failure', () async {
    // Arrange
    when(() => mockCloud.getUserData())
        .thenThrow(Exception('Server error'));

    // Act + Assert
    expect(
      () => controller.fetchUserProfile(),
      throwsA(isA<Exception>()),
    );
  });

  // --------------------------------------------------
  // updateProfileName
  // --------------------------------------------------

  test('updateProfileName returns success map on success', () async {
    // Arrange
    when(() => mockCloud.updateUserProfile(name: 'Ali'))
        .thenAnswer((_) async => {
              'ok': true,
              'message': 'Profile updated',
            });

    // Act
    final result =
        await controller.updateProfileName(name: 'Ali');

    // Assert
    expect(result['ok'], true);
    expect(result['message'], 'Profile updated');

    verify(() => mockCloud.updateUserProfile(name: 'Ali')).called(1);
  });

  test('updateProfileName throws exception on failure', () async {
    // Arrange
    when(() => mockCloud.updateUserProfile(name: any(named: 'name')))
        .thenThrow(Exception('Permission denied'));

    // Act + Assert
    expect(
      () => controller.updateProfileName(name: 'Ali'),
      throwsA(isA<Exception>()),
    );
  });
}
