import 'package:flutter/material.dart';

/// Reusable AppBar widget that displays the app logo and title
/// Used across all screens for consistent navigation
class AppBarWithLogo extends StatelessWidget implements PreferredSizeWidget {
  /// The title text to display in the app bar
  final String title;

  /// Optional action buttons (e.g., logout, notifications) to show on the right
  final List<Widget>? actions;

  /// Optional custom leading widget (if null, shows logo)
  final Widget? leading;

  /// Whether to center the title
  final bool centerTitle;

  const AppBarWithLogo({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    // Builds a standard AppBar with logo on the left and title
    // If leading is provided, it replaces the logo
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: leading != null ? 90 : null,
      title: Row(
        children: [
          if (leading == null)
            Image.asset(
              'images/logoBLOOD.png',
              height: 34,
              fit: BoxFit.contain,
            ),
          if (leading == null) const SizedBox(width: 10),
          if (!centerTitle)
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      actions: [
        ...?actions,
        if (actions != null && actions!.isNotEmpty) const SizedBox(width: 6),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
