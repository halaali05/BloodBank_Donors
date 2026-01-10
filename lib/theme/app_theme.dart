import 'package:flutter/material.dart';

/// App-wide theme constants and styles
/// This class contains all the colors, sizes, and reusable styles used throughout the app
class AppTheme {
  /// List of Jordanian governorates for location selection
  /// Used in registration, profile, and request creation
  static const List<String> jordanianGovernorates = [
    'Amman',
    'Zarqa',
    'Irbid',
    'Ajloun',
    'Jerash',
    'Mafraq',
    'Balqa',
    'Madaba',
    'Karak',
    'Tafilah',
    "Ma'an",
    'Aqaba',
  ];
  // ========== Colors ==========
  /// Primary brand color - deep red used for buttons, icons, and accents
  static const Color deepRed = Color(0xFF7A0009);

  /// Off-white background color for screens
  static const Color offWhite = Color(0xFFFDF7F6);

  /// Light gray color for card borders
  static const Color cardBorder = Color(0xFFE9E2E1);

  /// Soft background color for screens
  static const Color softBg = Color(0xFFF3F5F9);

  /// Light blue-gray color for input field backgrounds
  static const Color fieldFill = Color(0xFFF8F9FF);

  /// Gray color for input field underlines
  static const Color lineColor = Color(0xFFBFC7D2);

  /// Red color for urgent badges and warnings
  static const Color urgentRed = Color(0xFFC62828);

  /// Light red background for urgent badges
  static const Color urgentBg = Color(0xFFFFEBEE);

  /// Very light red background for urgent cards
  static const Color urgentCardBg = Color(0xFFFFF5F5);

  // ========== Border Radius ==========
  /// Standard border radius for cards and containers
  static const double borderRadius = 18.0;

  /// Small border radius for buttons and small elements
  static const double borderRadiusSmall = 12.0;

  /// Large border radius for header cards
  static const double borderRadiusLarge = 22.0;

  // ========== Padding ==========
  /// Standard padding used throughout the app
  static const double padding = 16.0;

  /// Small padding for tight spaces
  static const double paddingSmall = 12.0;

  /// Large padding for header sections
  static const double paddingLarge = 22.0;

  // ========== Shadows ==========
  /// Standard shadow for cards - subtle elevation
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 6)),
  ];

  /// Larger shadow for header cards and important elements
  static const List<BoxShadow> cardShadowLarge = [
    BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 8)),
  ];

  // ========== Reusable Decorations ==========
  /// Creates a standard card decoration with white background, border, and shadow
  /// Used for all card widgets throughout the app
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? cardBorder),
      boxShadow: shadow ?? cardShadow,
    );
  }

  /// Creates an input decoration with underline style
  /// Used in login, register, and forgot password screens
  static InputDecoration underlineInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[700]),
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: lineColor, width: 1),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: deepRed, width: 2),
      ),
    );
  }

  /// Creates an input decoration with outlined border style
  /// Used in forms and text fields
  static InputDecoration outlinedInputDecoration({
    required String label,
    IconData? icon,
    Color? fillColor,
    double? borderRadius,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[700]) : null,
      filled: true,
      fillColor: fillColor ?? fieldFill,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusSmall),
        borderSide: const BorderSide(color: Color(0xffd0d4f0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusSmall),
        borderSide: const BorderSide(color: Color(0xffd0d4f0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusSmall),
        borderSide: const BorderSide(color: deepRed, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// Creates the primary button style with deep red background
  /// Used for all main action buttons in the app
  static ButtonStyle primaryButtonStyle({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: deepRed,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 999),
      ),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  /// Standard app bar theme - white background, no elevation
  static AppBarTheme appBarTheme = const AppBarTheme(
    elevation: 0,
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    centerTitle: false,
  );
}
