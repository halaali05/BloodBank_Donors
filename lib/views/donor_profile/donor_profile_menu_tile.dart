import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Row on the main donor profile hub (Account, History, etc.).
class DonorProfileMenuTile extends StatelessWidget {
  final String index;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DonorProfileMenuTile({
    super.key,
    required this.index,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.deepRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            index,
            style: const TextStyle(
              color: AppTheme.deepRed,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Icon(icon, color: Colors.black54),
      ),
    );
  }
}
