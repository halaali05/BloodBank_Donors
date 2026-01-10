import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request_model.dart';
import '../common/urgent_badge.dart';

/// Card widget that displays a blood request
/// Used in the blood bank dashboard to show all active requests
class RequestCard extends StatelessWidget {
  /// The blood request data to display
  final BloodRequest request;
  
  /// Callback when delete button is pressed (only shown to request owner)
  final VoidCallback? onDelete;
  
  /// Callback when "View Donors" button is pressed
  final VoidCallback? onViewDonors;

  const RequestCard({
    super.key,
    required this.request,
    this.onDelete,
    this.onViewDonors,
  });

  @override
  Widget build(BuildContext context) {
    // Check if current user owns this request (can delete it)
    final bool canDelete =
        FirebaseAuth.instance.currentUser?.uid == request.bloodBankId;
    final bool isUrgent = request.isUrgent;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.deepRed.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    request.bloodType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.deepRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${request.units} units needed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isUrgent) ...[
                  const UrgentBadge(),
                  const SizedBox(width: 6),
                ],
                if (canDelete && onDelete != null) ...[
                  IconButton(
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.hospitalLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            if (request.details.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.details.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ],
            if (onViewDonors != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onViewDonors,
                  icon: const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: AppTheme.deepRed,
                  ),
                  label: const Text(
                    'Donors',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.deepRed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
