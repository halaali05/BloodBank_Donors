import 'package:flutter_test/flutter_test.dart';

import 'package:bloodbank_donors/models/pending_approval_model.dart';

void main() {

  group('PendingApproval.fromMap', () {

    test('creates model with full valid data',  () {

        final model = PendingApproval.fromMap(
          {
            'email': 'hospital@test.com',
            'role': 'hospital',
            'bloodBankName': 'Central Blood Bank',
            'location': 'Amman',
            'latitude': 31.95,
            'longitude': 35.91,
            'createdAt':
                '2025-01-01T00:00:00.000',
            'status': 'approved',
          },
          'uid1',
        );

        expect(model.uid, 'uid1');
        expect(model.email,'hospital@test.com');
        expect(model.role, 'hospital');
        expect(model.bloodBankName,'Central Blood Bank');
        expect(model.location, 'Amman');
        expect(model.latitude, 31.95);
        expect(model.longitude, 35.91);
        expect(model.createdAt,isNotNull);
        expect(model.status, 'approved');
      },
    );

    test('uses default values when missing',() {

        final model = PendingApproval.fromMap(
          {},
          'uid2',
        );

        expect(model.uid, 'uid2');
        expect(model.email, '');
        expect(model.role, 'hospital');
        expect(model.status,'awaiting_admin_approval');
      },
    );

    test('parses int timestamp',() {

        final model = PendingApproval.fromMap(
          {
            'createdAt': 1000,
          },
          'uid3',
        );

        expect(model.createdAt,DateTime.fromMillisecondsSinceEpoch(1000,),);
      },
    );

    test('parses firestore timestamp map',() {

        final model = PendingApproval.fromMap( {'createdAt': { '_seconds': 100, },},'uid4',);

        expect( model.createdAt, DateTime.fromMillisecondsSinceEpoch(100 * 1000, ),);
      },
    );

    test('parses latitude and longitude from int',() {

        final model = PendingApproval.fromMap(
          {
            'latitude': 31,
            'longitude': 35,
          },
          'uid5',
        );

        expect(model.latitude, 31.0);
        expect(model.longitude, 35.0);
      },
    );

    test('parses latitude and longitude from string',() {

        final model = PendingApproval.fromMap(
          {
            'latitude': '31.5',
            'longitude': '35.5',
          },
          'uid6',
        );

        expect(model.latitude, 31.5);
        expect(model.longitude, 35.5);
      },
    );

    test('returns null for invalid date',() {

        final model = PendingApproval.fromMap(
          {
            'createdAt': 'bad-date',
          },
          'uid7',
        );

        expect(model.createdAt, null);
      },
    );

    test('returns null for invalid doubles',() {
       final model = PendingApproval.fromMap(
          {
            'latitude': 'bad',
            'longitude': [],
          },
          'uid8',
        );

        expect(model.latitude, null);
        expect(model.longitude, null);
      },
    );

    test('handles DateTime createdAt directly',() {

        final now = DateTime.now();

        final model = PendingApproval.fromMap(
          {
            'createdAt': now,
          },
          'uid9',
        );

        expect(model.createdAt, now);
      },
    );
  });
}