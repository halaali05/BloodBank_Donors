import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

/// Utility class for showing dialogs
/// Centralizes dialog UI code for reusability
class DialogHelper {
  /// Shows a warning dialog
  static void showWarning({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      customHeader: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.orange,
        child: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  /// Shows a success dialog
  /// Returns a Future that completes when the dialog is dismissed
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    final completer = Completer<void>();
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      customHeader: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.green,
        child: const Icon(Icons.check_circle, color: Colors.white, size: 30),
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    ).show().then((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  /// Shows an error dialog
  static void showError({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      customHeader: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.red,
        child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  /// Shows an info dialog
  /// Returns a Future that completes when the dialog is dismissed
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    final completer = Completer<void>();
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.bottomSlide,
      customHeader: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.info_outline, color: Colors.white, size: 30),
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    ).show().then((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }
}
