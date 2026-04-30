import 'package:flutter/material.dart';

/// Centered loading spinner widget
/// Used to show loading state while fetching data
class LoadingIndicator extends StatelessWidget {
  /// Optional custom color for the spinner
  final Color? color;

  /// Optional custom size (width and height)
  final double? size;

  const LoadingIndicator({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: color != null
          ? AlwaysStoppedAnimation<Color>(color!)
          : null,
    );
    return Center(
      child: size != null
          ? SizedBox(width: size, height: size, child: indicator)
          : indicator,
    );
  }
}
