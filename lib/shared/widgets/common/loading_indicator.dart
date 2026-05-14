import 'package:flutter/material.dart';

/// Centered loading or status card with optional message and retry action.
///
/// When showing an error or offline message after a request, set [showSpinner]
/// to false so the spinner does not keep running next to the message.
class LoadingIndicator extends StatelessWidget {
  final Color? color;

  final double? size;

  final String? message;

  final Color? messageColor;

  final bool showSpinner;

  /// When [showSpinner] is false, uses a wifi icon if true (offline tone).
  final bool connectivityIssue;

  final VoidCallback? onRetry;

  final String retryLabel;

  const LoadingIndicator({
    super.key,
    this.color,
    this.size,
    this.message,
    this.messageColor,
    this.showSpinner = true,
    this.connectivityIssue = false,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    final Color resolvedMsgColor =
        messageColor ?? (showSpinner ? Colors.black54 : Colors.black87);

    Widget? leading;
    if (!showSpinner && shouldShowMessage) {
      leading = Icon(
        connectivityIssue ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
        size: 44,
        color: connectivityIssue
            ? Colors.deepOrange.shade800
            : Colors.red.shade700,
      );
    }

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(height: 14),
        ],
        if (showSpinner) indicatorWidget,
        if (showSpinner && shouldShowMessage) const SizedBox(height: 12),
        if (shouldShowMessage)
          Text(
            message!.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resolvedMsgColor,
              fontSize: 14,
              height: 1.35,
              fontWeight:
                  messageColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              child: inner,
            ),
          ),
        ),
      ),
    );
  }
}
