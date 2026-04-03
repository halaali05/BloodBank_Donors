import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request_model.dart';
import '../common/urgent_badge.dart';

/// Card widget that displays a blood request (blood bank dashboard).
class RequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDonors;
  final VoidCallback? onTapAcceptances;
  final VoidCallback? onTapRejections;
  final VoidCallback? onMarkCompleted;

  const RequestCard({
    super.key,
    required this.request,
    this.onDelete,
    this.onViewDonors,
    this.onTapAcceptances,
    this.onTapRejections,
    this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final bool canDelete =
        FirebaseAuth.instance.currentUser?.uid == request.bloodBankId;
    final bool isUrgent = request.isUrgent;
    final bool isCompleted = request.isCompleted;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),

         // 🔴 border إذا urgent
          border: isUrgent? Border.all(color: const Color.fromARGB(255, 194, 87, 79), width: 1.5) : null,

        boxShadow: [
        BoxShadow(
        color: isUrgent? const Color.fromARGB(255, 189, 79, 71).withOpacity(0.5): Colors.black12,
        blurRadius: isUrgent ? 12 : 6,
        offset: const Offset(0, 3),
      ),
  ],
),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           Row(
  children: [
    // 🩸 Blood Type Badge
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.withOpacity(0.15)
            : AppTheme.deepRed.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        request.bloodType,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: AppTheme.deepRed,
        ),
      ),
    ),

    const SizedBox(width: 12),

    // 🔢 Units
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${request.units}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text(
          'units needed',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    ),

    const Spacer(),

    if (isUrgent) ...[
      const UrgentBadge(),
      const SizedBox(width: 6),
    ],
    if (canDelete && onDelete != null)
  IconButton(
    tooltip: 'Delete',
    icon: const Icon(
      Icons.delete_outline,
      color: Colors.red,
      size: 20,
    ),
    onPressed: onDelete,
  ),
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
            if (onTapAcceptances != null || onTapRejections != null) ...[
              const SizedBox(height: 10),
              const Text(
                'Donor responses',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onTapAcceptances != null)
                    _CountLink(
                      icon: Icons.check_circle_outline,
                      label: 'Acceptances',
                      count: request.acceptedCount,
                      color: Colors.green.shade800,
                      onTap: onTapAcceptances!,
                    ),
                  if (onTapRejections != null)
                    _CountLink(
                      icon: Icons.cancel_outlined,
                      label: 'Rejections',
                      count: request.rejectedCount,
                      color: Colors.red.shade800,
                      onTap: onTapRejections!,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Tap a count to see donor names and emails.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ],
            if (onViewDonors != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isCompleted && onMarkCompleted != null)
                    TextButton.icon(
                      onPressed: onMarkCompleted,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green,
                      ),
                      label: const Text(
                        'Complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  TextButton.icon(
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountLink extends StatelessWidget {
  const _CountLink({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
