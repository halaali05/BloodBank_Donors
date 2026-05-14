import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../controllers/donor_profile_controller.dart';
import '../models/donor_medical_report.dart';
import '../models/user_model.dart' as models;
import 'auth_service.dart';
import '../views/chat_screen.dart';
import '../views/dashboard/blood_bank_dashboard_screen.dart';
import '../views/dashboard/donor_dashboard_screen.dart';
import '../views/donor_management/donor_management_screen.dart';
import '../views/donor_profile/donor_profile_donation_history_page.dart';
import '../views/donor_profile/donor_profile_reports_page.dart';
import '../views/notifications_screen.dart';
import '../views/onboarding/welcome_screen.dart';
import '../views/request_details_screen.dart';
import '../views/support/support_ticket_detail_screen.dart';
import '../models/support_ticket_model.dart';
import 'requests_service.dart';

/// Routes the user after a push or local notification is opened.
/// Shared by [FCMService] and [LocalNotifService] so navigation stays in one place.
class NotificationNavigationService {
  NotificationNavigationService._();
  static final NotificationNavigationService instance = NotificationNavigationService._();

  FirebaseAuth Function() authFactory = () => FirebaseAuth.instance;

  AuthService Function() authServiceFactory = () => AuthService();

  RequestsService Function() requestsFactory = () => RequestsService.instance;

BuildContext? Function() contextFactory =  () => navigatorKey.currentContext;


  /// Parse JSON payload from [flutter_local_notifications] and route.
  void openFromPayloadJson(String payload) {
    if (payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        openFromData(
          Map<String, dynamic>.from(decoded),
          fromNotificationTap: true,
        );
        return;
      }
    } catch (_) {
      // Fall through to legacy plain request id string.
    }
    openFromData(
      <String, dynamic>{'type': 'request', 'requestId': payload},
      fromNotificationTap: true,
    );
  }

  /// Same routing as FCM / web `notificationData` query (map from message.data).
  void openFromData(
    Map<String, dynamic> data, {
    bool fromNotificationTap = true,
  }) {
    _handleNotificationClick(data, fromNotificationTap: fromNotificationTap);
  }

  void _handleNotificationClick(
    Map<String, dynamic> data, {
    required bool fromNotificationTap,
  }) async {
    final BuildContext? context = contextFactory();

    if (context == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationClick(
          data,
          fromNotificationTap: fromNotificationTap,
        );
      });
      return;
    }

    bool isAuthenticated = false;
    User? user;

    try {
      user = authFactory().currentUser;

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
          user = await authFactory()
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
      final authService = authServiceFactory();
      final userData = await authService.getUserData(user.uid);

      if (!context.mounted) return;

      if (userData == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        return;
      }

      final notificationType =
          (data['type']?.toString() ?? 'request').trim().toLowerCase();
      final requestId = data['requestId']?.toString() ?? '';
      final ticketId = data['ticketId']?.toString() ?? '';
      final recipientId = data['recipientId']?.toString() ?? '';
      final senderId = data['senderId']?.toString() ?? '';

      Future<void> openTarget(WidgetBuilder builder) async {
        if (!context.mounted) return;
        if (fromNotificationTap) {
          // Deep link behavior for notification taps (cold start/background/foreground).
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: builder),
            (route) => false,
          );
        } else {
          // Standard in-app navigation keeps back stack.
          Navigator.of(context).push(MaterialPageRoute(builder: builder));
        }
      }

      // ── جديد: Account Approved notification ──
      if (notificationType == 'account_approved') {
        final freshUserData = await authServiceFactory().getUserData(user.uid);
        if (!context.mounted) return;
        if (freshUserData != null &&
            freshUserData.role == models.UserRole.hospital) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => BloodBankDashboardScreen(
                bloodBankName: freshUserData.bloodBankName ?? 'Blood Bank',
                location: freshUserData.location ?? 'Unknown',
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
        return;
      }

      // ── جديد: Account Rejected notification ──
      if (notificationType == 'account_rejected') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Registration Not Approved'),
                ],
              ),
              content: const Text(
                'Your blood bank registration was reviewed and was not approved.\n\n'
                'Please contact support or register again with the correct information.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
        return;
      }

      if (notificationType == 'support_reply' && ticketId.isNotEmpty) {
        final senderRole = userData.role == models.UserRole.hospital
            ? TicketSenderRole.hospital
            : TicketSenderRole.donor;
        final senderName = userData.role == models.UserRole.hospital
            ? (userData.bloodBankName ?? userData.fullName)
            : userData.fullName;
        await openTarget(
          (_) => SupportTicketDetailScreen(
            ticketId: ticketId,
            senderRole: senderRole,
            senderName: senderName,
          ),
        );
        return;
      }

      if (notificationType == 'chat' && requestId.isNotEmpty) {
        await openTarget(
          (_) => ChatScreen(
            requestId: requestId,
            initialMessage: '',
            recipientId: senderId.isNotEmpty
                ? senderId
                : (recipientId.isNotEmpty ? recipientId : null),
          ),
        );
        return;
      }

      if (notificationType == 'appointment_scheduled' && requestId.isNotEmpty) {
        if (userData.role == models.UserRole.hospital) {
          await openTarget(
            (_) => _HospitalDonorManagementRoute(requestId: requestId),
          );
        } else {
          await openTarget((_) => const _DonorNotificationHistoryRoute());
        }
        return;
      }

      if (notificationType == 'medical_report_saved') {
        if (userData.role == models.UserRole.donor) {
          await openTarget((_) => const _DonorNotificationReportsRoute());
        } else if (requestId.isNotEmpty) {
          await openTarget(
            (_) => _HospitalDonorManagementRoute(requestId: requestId),
          );
        }
        return;
      }

      if (notificationType == 'request' && requestId.isNotEmpty) {
        await openTarget((_) => RequestDetailsScreen(requestId: requestId));
        return;
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

class _DonorNotificationHistoryRoute extends StatefulWidget {
  const _DonorNotificationHistoryRoute();

  @override
  State<_DonorNotificationHistoryRoute> createState() =>
      _DonorNotificationHistoryRouteState();
}

class _DonorNotificationHistoryRouteState
    extends State<_DonorNotificationHistoryRoute> {
  final DonorProfileController _controller = DonorProfileController();
  late Future<List<DonorMedicalReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _controller.fetchDonationHistory(includeActiveProgress: true);
  }

  Future<List<DonorMedicalReport>> _reload() =>
      _controller.fetchDonationHistory(includeActiveProgress: true);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DonorMedicalReport>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading your donation history...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }
        return DonorProfileDonationHistoryPage(
          initialReports: snapshot.data ?? const [],
          initialLoading: false,
          reloadReports: _reload,
        );
      },
    );
  }
}

class _DonorNotificationReportsRoute extends StatefulWidget {
  const _DonorNotificationReportsRoute();

  @override
  State<_DonorNotificationReportsRoute> createState() =>
      _DonorNotificationReportsRouteState();
}

class _DonorNotificationReportsRouteState
    extends State<_DonorNotificationReportsRoute> {
  final DonorProfileController _controller = DonorProfileController();
  late Future<List<DonorMedicalReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _controller.fetchDonationHistory(includeActiveProgress: false);
  }

  Future<List<DonorMedicalReport>> _reload() =>
      _controller.fetchDonationHistory(includeActiveProgress: false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DonorMedicalReport>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading your reports...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }
        return DonorProfileReportsPage(
          initialReports: snapshot.data ?? const [],
          initialLoading: false,
          reloadReports: _reload,
        );
      },
    );
  }
}

class _HospitalDonorManagementRoute extends StatefulWidget {
  final String requestId;
  const _HospitalDonorManagementRoute({required this.requestId});

  @override
  State<_HospitalDonorManagementRoute> createState() =>
      _HospitalDonorManagementRouteState();
}

class _HospitalDonorManagementRouteState
    extends State<_HospitalDonorManagementRoute> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = RequestsService.instance.getRequestById(widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading donor management details...',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return RequestDetailsScreen(requestId: widget.requestId);
        }
        return DonorManagementScreen(request: snapshot.data);
      },
    );
  }
}
