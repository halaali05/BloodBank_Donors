import 'package:flutter/material.dart';

import 'error_message_helper.dart';

/// Standard success / error toasts plus [humanizeError] helpers.
class SnackBarHelper {
  SnackBarHelper._();

  static String stripExceptionPrefix(String message) =>
      message.replaceFirst('Exception: ', '');

  static SnackBar _bar({
    required Widget content,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: content,
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
    );
  }

  static void show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _bar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Custom body (links, formatted text).
  static void showContent({
    required BuildContext context,
    required Widget content,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _bar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green.shade700,
      duration: duration,
    );
  }

  static void failure(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.red.shade800,
      duration: duration,
      action: action,
    );
  }

  /// Maps any thrown value into a readable line (Firebase, network, etc.).
  static void failureFrom(BuildContext context, Object err) =>
      failure(context, ErrorMessageHelper.humanize(err));

  static void notice(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.blueGrey.shade800,
      duration: duration,
    );
  }
}
