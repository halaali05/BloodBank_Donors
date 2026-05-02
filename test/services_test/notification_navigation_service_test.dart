import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:bloodbank_donors/services/notification_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = NotificationNavigationService.instance;

  // =========================
  // JSON PARSING
  // =========================

  group('openFromPayloadJson', () {
    test('parses valid JSON without crashing', () {
      final payload = jsonEncode({
        'requestId': '123',
        'type': 'chat',
        'senderId': 'A',
        'recipientId': 'B',
      });

      service.openFromPayloadJson(payload);
    });

    test('handles invalid JSON gracefully', () {
      service.openFromPayloadJson('invalid-json');
    });

    test('handles non-map JSON', () {
      service.openFromPayloadJson(jsonEncode(['not', 'map']));
    });

    test('handles empty payload', () {
      service.openFromPayloadJson('');
    });

    test('handles missing fields in JSON', () {
      final payload = jsonEncode({
        'requestId': '123',
      });

      service.openFromPayloadJson(payload);
    });

    test('handles payload as plain string (fallback)', () {
      service.openFromPayloadJson('simple_id');
    });
  });

  // =========================
  // openFromData
  // =========================

  group('openFromData', () {
    test('does not crash with minimal data', () {
      service.openFromData({});
    });

    test('does not crash with partial data', () {
      service.openFromData({
        'type': 'chat',
      });
    });

    test('handles full data structure', () {
      service.openFromData({
        'requestId': '123',
        'type': 'chat',
        'senderId': 'A',
        'recipientId': 'B',
      });
    });
  });

  // =========================
  // CONTEXT NULL BRANCH
  // =========================

  group('context handling', () {
    test('retries when context is null (no crash)', () async {
      // في test environment navigatorKey.currentContext = null
      service.openFromData({'type': 'request'});

      // ننتظر retry (500ms)
      await Future.delayed(const Duration(milliseconds: 600));

      // إذا وصلنا هون بدون exception → pass
    });
  });

  // =========================
  // EDGE CASES
  // =========================

  group('edge cases', () {
    test('handles unknown notification type', () {
      service.openFromData({
        'type': 'unknown_type',
        'requestId': '123',
      });
    });

    test('handles empty requestId in chat type', () {
      service.openFromData({
        'type': 'chat',
        'requestId': '',
      });
    });

    test('handles null values in map', () {
      service.openFromData({
        'type': null,
        'requestId': null,
        'senderId': null,
        'recipientId': null,
      });
    });
  });
}