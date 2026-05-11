import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bloodbank_donors/controllers/admin_controller.dart';
import 'package:bloodbank_donors/models/blood_request_model.dart';
import 'package:bloodbank_donors/models/user_model.dart';
import 'package:bloodbank_donors/services/cloud_functions_service.dart';

// ================= MOCKS =================

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}


void main() {
  late MockCloudFunctionsService mockCloud;
  late AdminController controller;

  setUp(() {
    mockCloud = MockCloudFunctionsService();

    controller = AdminController(
      cloudFunctions: mockCloud,
    );
  });

  // ================= REQUESTS =================

  group('fetchAllRequests', () {
    test('returns mapped requests', () async {
        when(
          () => mockCloud.getAdminRequests(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'requests': [
              {
                'id': 'r1',
                'bloodBankName': 'Bank1',
                'units': 2,
                'acceptedCount': 1,
                'isCompleted': false,
                'isUrgent': true,
              }
            ]
          },
        );

        final result =
            await controller.fetchAllRequests();

        expect(result.length, 1);
        expect(result.first.id, 'r1');
      },
    );

    test('returns empty when requests invalid',() async {
        when(
          () => mockCloud.getAdminRequests(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'requests': 'invalid',
          },
        );

        final result =
            await controller.fetchAllRequests();

        expect(result, isEmpty);
      },
    );

    test('throws exception on failure',() async {
        when(
          () => mockCloud.getAdminRequests(
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => controller.fetchAllRequests(),
          throwsException,
        );
      },
    );
  });

  // ================= REQUEST ACTIONS =================

  group('request actions', () {
    test('deleteRequest calls service',() async {
        when(
          () => mockCloud.deleteRequest(
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => {});

        await controller.deleteRequest('r1');

        verify(
          () => mockCloud.deleteRequest(
            requestId: 'r1',
          ),
        ).called(1);
      },
    );

    test('markCompleted calls service',() async {
        when(
          () => mockCloud.markRequestCompleted(
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((_) async => {});

        await controller.markCompleted('r1');

        verify(
          () => mockCloud.markRequestCompleted(
            requestId: 'r1',
          ),
        ).called(1);
      },
    );
  });

  // ================= DONORS =================

  group('fetchDonors', () {
    test('returns only donors',() async {
        when(
          () => mockCloud.getDonors(
            bloodType: any(named: 'bloodType'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'donors': [
              {
                'uid': 'd1',
                'email': 'd@test.com',
                'role': 'donor',
              },
              {
                'uid': 'h1',
                'email': 'h@test.com',
                'role': 'hospital',
              },
            ]
          },
        );

        final result =
            await controller.fetchDonors();

        expect(result.length, 1);
        expect(
          result.first.role,
          UserRole.donor,
        );
      },
    );

    test('returns empty when donors invalid',() async {
        when(
          () => mockCloud.getDonors(
            bloodType: any(named: 'bloodType'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'donors': 'bad',
          },
        );

        final result =
            await controller.fetchDonors();

        expect(result, isEmpty);
      },
    );

    test('throws exception on donors failure',() async {
        when(
          () => mockCloud.getDonors(
            bloodType: any(named: 'bloodType'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception());

        expect(
          () => controller.fetchDonors(),
          throwsException,
        );
      },
    );
  });

  // ================= PENDING APPROVALS =================

  group('pending approvals', () {
    test('fetchPendingApprovals returns mapped approvals', () async {
        when(
          () => mockCloud.getPendingApprovals(),
        ).thenAnswer(
          (_) async => [
            {
              'uid': 'u1',
              'email': 'test@test.com',
            }
          ],
        );

        final result =
            await controller.fetchPendingApprovals();

        expect(result.length, 1);
      },
    );

    test('fetchPendingApprovals throws exception',() async {
        when(
          () => mockCloud.getPendingApprovals(),
        ).thenThrow(Exception());

        expect(
          () => controller.fetchPendingApprovals(),
          throwsException,
        );
      },
    );

    test('approvePendingUser calls service',() async {
        when(
          () => mockCloud.approvePendingUser(
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async {});

        await controller.approvePendingUser('u1');

        verify(
          () => mockCloud.approvePendingUser(
            uid: 'u1',
          ),
        ).called(1);
      },
    );

    test('rejectPendingUser calls service',() async {
        when(
          () => mockCloud.rejectPendingUser(
            uid: any(named: 'uid'),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) async {});

        await controller.rejectPendingUser(
          'u1',
          reason: 'bad docs',
        );

        verify(
          () => mockCloud.rejectPendingUser(
            uid: 'u1',
            reason: 'bad docs',
          ),
        ).called(1);
      },
    );
  });

  // ================= STATISTICS =================

  group('computeStats', () {

    test('computeStats counts temporarily restricted donors', () {
    final donors = [
      User(
        uid: 'u1',
        email: 'a@test.com',
        role: UserRole.donor,
        restrictedUntil:
            DateTime.now().add(
          const Duration(days: 1),
        ),
      ),
      User(
        uid: 'u2',
        email: 'b@test.com',
        role: UserRole.donor,
        nextDonationEligibleAt:
            DateTime.now().add(
          const Duration(days: 2),
        ),
      ),
    ];

    final stats =
        controller.computeStats(
      [],
      donors,
    );

    expect(
      stats.restrictedDonors,
      2,
    );
  },
);

    test('calculates correct values',() {
        final requests = [
          BloodRequest(
            id: 'r1',
            bloodBankName: 'Bank1',
            units: 2,
            acceptedCount: 1,
            isCompleted: false,
            isUrgent: true,
            bloodType: 'A+',
            bloodBankId: 'bb1',
          ),
          BloodRequest(
            id: 'r2',
            bloodBankName: 'Bank1',
            units: 1,
            acceptedCount: 2,
            isCompleted: true,
            bloodType: 'A+',
            isUrgent: false,
            bloodBankId: 'bb1',
          ),
        ];

        final donors = [
          User(
            uid: 'u1',
            email: 'a@test.com',
            role: UserRole.donor,
            bloodType: 'A+',
            location: 'Amman',
          ),
          User(
            uid: 'u2',
            email: 'b@test.com',
            role: UserRole.donor,
            bloodType: 'A+',
            location: 'Zarqa',
            isPermanentlyBlocked: true,
          ),
        ];

        final stats =
            controller.computeStats(
          requests,
          donors,
        );

        expect(stats.totalRequests, 2);
        expect(stats.activeRequests, 1);
        expect(stats.completedRequests, 1);
        expect(stats.urgentRequests, 1);
        expect(stats.totalUnitsNeeded, 2);
        expect(stats.totalAcceptances, 3);
        expect(stats.totalDonors, 2);
        expect(stats.restrictedDonors, 1);

        expect(
          stats.bloodTypeDistribution['A+'],
          2,
        );

        expect(
          stats.requestsPerBank['Bank1'],
          2,
        );

        expect(
          stats.donorsPerGovernorate['Amman'],
          1,
        );
      },
    );

    test('handles empty lists',() {
        final stats =
            controller.computeStats([], []);

        expect(stats.totalRequests, 0);
        expect(stats.activeRequests, 0);
        expect(stats.completedRequests, 0);
        expect(stats.urgentRequests, 0);
        expect(stats.totalUnitsNeeded, 0);
        expect(stats.totalAcceptances, 0);
        expect(stats.totalDonors, 0);
        expect(stats.restrictedDonors, 0);

        expect(
          stats.bloodTypeDistribution,
          isEmpty,
        );

        expect(
          stats.requestsPerBank,
          isEmpty,
        );

        expect(
          stats.donorsPerGovernorate,
          isEmpty,
        );
      },
    );
  });
}