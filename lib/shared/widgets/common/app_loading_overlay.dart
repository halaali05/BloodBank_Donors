import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Dimmed full-screen layer with a centered card — use as a [Stack] child for
/// blocking operations (login, form submit). Set [showProgress] to false when
/// the request has finished so the spinner never runs alongside a result message.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.visible,
    required this.showProgress,
    required this.message,
    this.isError = false,
    this.isSuccess = false,
    this.progressColor,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.absorbPointers = true,
  });

  final bool visible;

  /// When false, the request is complete — only the message / result icons show.
  final bool showProgress;

  final String message;

  final bool isError;

  final bool isSuccess;

  final Color? progressColor;

  final VoidCallback? onRetry;

  final String retryLabel;

  /// When false, taps pass through (e.g. rare cases); usually keep true while visible.
  final bool absorbPointers;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final trimmed = message.trim();
    final hasText = trimmed.isNotEmpty;

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showProgress) ...[
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: progressColor ?? AppTheme.deepRed,
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : isError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 46,
                    color: isSuccess
                        ? Colors.green.shade600
                        : isError
                        ? Colors.red.shade700
                        : AppTheme.deepRed,
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasText)
                  Text(
                    trimmed,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight:
                          showProgress ? FontWeight.w500 : FontWeight.w600,
                      color: showProgress
                          ? Colors.black87
                          : (isError
                                ? Colors.red.shade900
                                : Colors.black87),
                    ),
                  ),
                if (onRetry != null && !showProgress) ...[
                  const SizedBox(height: 18),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: Text(retryLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final layer = Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(child: card),
    );

    return Positioned.fill(
      child: absorbPointers ? AbsorbPointer(child: layer) : layer,
    );
  }
}
