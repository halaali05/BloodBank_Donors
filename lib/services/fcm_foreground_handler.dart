import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'cloud_functions_service.dart';
import 'local_notif_service.dart';
import '../notifications/web_foreground_notification.dart';

/// Foreground FCM handling: donor blood-type filter, then **local** or **web** display.
/// Does not call Cloud Functions for token upload (see [FcmCloudSyncService]).
class FcmForegroundHandler {
  FcmForegroundHandler._();
  static final FcmForegroundHandler instance = FcmForegroundHandler._();

  static List<String>? _compatibleBloodTypes(String? donorBloodType) {
    switch (donorBloodType?.trim()) {
      case 'O-':
        return ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];
      case 'O+':
        return ['O+', 'A+', 'B+', 'AB+'];
      case 'A-':
        return ['A-', 'A+', 'AB-', 'AB+'];
      case 'A+':
        return ['A+', 'AB+'];
      case 'B-':
        return ['B-', 'B+', 'AB-', 'AB+'];
      case 'B+':
        return ['B+', 'AB+'];
      case 'AB-':
        return ['AB-', 'AB+'];
      case 'AB+':
        return ['AB+'];
      default:
        return null;
    }
  }

  Future<void> handleForegroundMessage(RemoteMessage message) async {
    final String requestId = message.data['requestId']?.toString() ?? '';
    final String type = message.data['type']?.toString() ?? 'request';
    final bool isUrgent =
        (message.data['isUrgent']?.toString().toLowerCase() ?? '') == 'true';

    if (type == 'request') {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final authService = AuthService();
          final userData = await authService.getUserData(user.uid);
          final donorBloodType = userData?.bloodType?.trim() ?? '';

          debugPrint(
            'FCM filter: donorBloodType=$donorBloodType, requestId=$requestId',
          );

          if (donorBloodType.isNotEmpty) {
            final compatible = _compatibleBloodTypes(donorBloodType);
            if (compatible != null) {
              String notifBloodType =
                  message.data['bloodType']?.toString().trim() ?? '';

              debugPrint(
                'FCM filter: notifBloodType from data=$notifBloodType',
              );

              if (notifBloodType.isEmpty && requestId.isNotEmpty) {
                try {
                  final result = await CloudFunctionsService().getRequests(
                    limit: 100,
                  );
                  final requests = result['requests'] as List<dynamic>? ?? [];
                  for (final r in requests) {
                    final map = r as Map<String, dynamic>;
                    if (map['id']?.toString() == requestId) {
                      notifBloodType =
                          map['bloodType']?.toString().trim() ?? '';
                      break;
                    }
                  }
                  debugPrint(
                    'FCM filter: notifBloodType from request=$notifBloodType',
                  );
                } catch (e) {
                  debugPrint('FCM filter: failed to fetch request: $e');
                }
              }

              debugPrint(
                'FCM filter: compatible=$compatible, notifBloodType=$notifBloodType',
              );

              if (notifBloodType.isNotEmpty &&
                  !compatible.contains(notifBloodType)) {
                debugPrint('FCM filter: BLOCKED notification (not compatible)');
                return;
              }
              debugPrint('FCM filter: ALLOWED notification');
            }
          }
        }
      } catch (e) {
        debugPrint('FCM filter: error, showing notification anyway: $e');
      }
    }

    final String title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'Blood Request';

    final String body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        'New blood request available';

    final payload = {
      'type': type,
      'requestId': requestId,
      'senderId': message.data['senderId']?.toString() ?? '',
      'recipientId': message.data['recipientId']?.toString() ?? '',
    };

    if (kIsWeb) {
      showWebForegroundNotification(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(payload),
      );
      return;
    }

    LocalNotifService.instance.show(
      title: title,
      body: body,
      payload: jsonEncode(payload),
      isUrgent: type == 'request' ? isUrgent : false,
    );
  }
}
