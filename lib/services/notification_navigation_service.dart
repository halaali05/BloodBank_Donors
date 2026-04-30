import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/user_model.dart' as models;
import 'auth_service.dart';
import '../views/chat_screen.dart';
import '../views/dashboard/blood_bank_dashboard_screen.dart';
import '../views/dashboard/donor_dashboard_screen.dart';
import '../views/notifications_screen.dart';
import '../views/onboarding/welcome_screen.dart';

/// Routes the user after a push or local notification is opened.
/// Shared by [FCMService] and [LocalNotifService] so navigation stays in one place.
class NotificationNavigationService {
  NotificationNavigationService._();
  static final NotificationNavigationService instance =
      NotificationNavigationService._();

  /// Parse JSON payload from [flutter_local_notifications] and route.
  void openFromPayloadJson(String payload) {
    String requestId = '';
    String type = 'request';
    String senderId = '';
    String recipientId = '';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        requestId = decoded['requestId']?.toString() ?? '';
        type = decoded['type']?.toString() ?? 'request';
        senderId = decoded['senderId']?.toString() ?? '';
        recipientId = decoded['recipientId']?.toString() ?? '';
      } else {
        requestId = payload;
      }
    } catch (_) {
      requestId = payload;
    }
    openFromData(<String, dynamic>{
      'requestId': requestId,
      'type': type,
      'senderId': senderId,
      'recipientId': recipientId,
    });
  }

  /// Same routing as FCM / web `notificationData` query (map from message.data).
  void openFromData(Map<String, dynamic> data) {
    _handleNotificationClick(data);
  }

  void _handleNotificationClick(Map<String, dynamic> data) async {
    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(data);
      });
      return;
    }

    bool isAuthenticated = false;
    User? user;

    try {
      user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          await user.getIdToken();
          isAuthenticated = true;
        } catch (_) {
          isAuthenticated = false;
          user = null;
        }
      }

      if (!isAuthenticated && user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .timeout(const Duration(seconds: 1))
              .first;

          if (user != null) {
            try {
              await user.getIdToken();
              isAuthenticated = true;
            } catch (_) {
              isAuthenticated = false;
              user = null;
            }
          }
        } catch (_) {
          isAuthenticated = false;
          user = null;
        }
      }
    } catch (_) {
      isAuthenticated = false;
      user = null;
    }

    if (!context.mounted) return;

    if (!isAuthenticated || user == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      return;
    }

    try {
      final authService = AuthService();
      final userData = await authService.getUserData(user.uid);

      if (!context.mounted) return;

      if (userData == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        return;
      }

      final notificationType = data['type']?.toString() ?? 'request';
      final requestId = data['requestId']?.toString() ?? '';
      final recipientId = data['recipientId']?.toString() ?? '';
      final senderId = data['senderId']?.toString() ?? '';

      if (notificationType == 'chat' && requestId.isNotEmpty) {
        if (userData.role == models.UserRole.donor) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
            (route) => false,
          );
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(requestId: requestId, initialMessage: ''),
                ),
              );
            }
          });
          return;
        }
        if (userData.role == models.UserRole.hospital) {
          final bloodBankName = userData.bloodBankName ?? 'Blood Bank';
          final location = userData.location ?? 'Unknown';
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => BloodBankDashboardScreen(
                bloodBankName: bloodBankName,
                location: location,
              ),
            ),
            (route) => false,
          );
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId: requestId,
                    initialMessage: '',
                    recipientId: senderId.isNotEmpty
                        ? senderId
                        : (recipientId.isNotEmpty ? recipientId : null),
                  ),
                ),
              );
            }
          });
          return;
        }
      }

      if (userData.role == models.UserRole.donor) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
          (route) => false,
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(initialTabIndex: 1),
              ),
            );
          }
        });
      } else if (userData.role == models.UserRole.hospital) {
        final bloodBankName = userData.bloodBankName ?? 'Blood Bank';
        final location = userData.location ?? 'Unknown';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BloodBankDashboardScreen(
              bloodBankName: bloodBankName,
              location: location,
            ),
          ),
          (route) => false,
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(initialTabIndex: 1),
              ),
            );
          }
        });
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
}
