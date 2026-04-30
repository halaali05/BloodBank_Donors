import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Displays an error message in a centered card
/// Used when data loading fails or errors occur
/// Optionally shows a retry button
class ErrorBox extends StatelessWidget {
  /// Error title (defaults to "Error")
  final String title;

  /// Error message to display
  final String message;

  /// Optional callback for retry button
  final VoidCallback? onRetry;

  const ErrorBox({
    super.key,
    this.title = 'Error',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.padding),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.padding),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 34),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: AppTheme.primaryButtonStyle(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
