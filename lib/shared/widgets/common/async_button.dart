import 'package:flutter/material.dart';

/// Disables taps while [isBusy]; shows inline spinner inside the button.
class AsyncElevatedButton extends StatelessWidget {
  const AsyncElevatedButton({
    super.key,
    required this.label,
    required this.isBusy,
    this.onPressed,
    this.style,
    this.minimumSize = const Size.fromHeight(48),
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Size minimumSize;

  @override
  Widget build(BuildContext context) {
    final overlay = Theme.of(context).colorScheme.onPrimary;
    final baseStyle = ElevatedButton.styleFrom(minimumSize: minimumSize);
    return ElevatedButton(
      style: style != null ? baseStyle.merge(style!) : baseStyle,
      onPressed: isBusy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isBusy
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: overlay,
                ),
              )
            : Text(label, key: ValueKey(label)),
      ),
    );
  }
}

/// Same pattern for outlined buttons.
class AsyncOutlinedButton extends StatelessWidget {
  const AsyncOutlinedButton({
    super.key,
    required this.label,
    required this.isBusy,
    this.onPressed,
    this.style,
    this.minimumSize = const Size.fromHeight(48),
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Size minimumSize;

  @override
  Widget build(BuildContext context) {
    final baseStyle = OutlinedButton.styleFrom(minimumSize: minimumSize);
    return OutlinedButton(
      style: style != null ? baseStyle.merge(style!) : baseStyle,
      onPressed: isBusy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isBusy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, key: ValueKey(label)),
      ),
    );
  }
}
