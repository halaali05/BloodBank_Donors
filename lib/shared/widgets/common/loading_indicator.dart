import 'package:flutter/material.dart';

/// Centered loading spinner widget
/// Used to show loading state while fetching data
class LoadingIndicator extends StatelessWidget {
  /// Optional custom color for the spinner
  final Color? color;

  /// Optional custom size (width and height)
  final double? size;

  /// Optional message shown under the spinner.
  final String? message;

  const LoadingIndicator({super.key, this.color, this.size, this.message});

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: color != null
          ? AlwaysStoppedAnimation<Color>(color!)
          : null,
    );
    final shouldShowMessage = (message ?? '').trim().isNotEmpty;
    final indicatorWidget = size != null
        ? SizedBox(width: size, height: size, child: indicator)
        : indicator;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicatorWidget,
          if (shouldShowMessage) ...[
            const SizedBox(height: 10),
            Text(
              message!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
