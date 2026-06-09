// ⚠️ DEPRECATED — Migrating to lib/cores/constants/tokens.dart
// Phase 2-3 will replace all imports with tokens.dart.
// Use Theme.of(context).colorScheme.xxx for theme-aware colors.
// Use AppColorTokens (in tokens.dart) only when no scheme equivalent exists.
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0fba39);
  static const Color primary2 = Color(0xFF80d58b);
  static const Color primaryDark = Color(0xFF4490ed);
  static const Color secondary = Color(0xFFFF8040);
  static const Color backdrop = Color(0xFFf9fafb);

  static const Color errorLight = Color(0xFFff0033);

  static const Color buttonDisabled = Color(0xFFB3B3B3);

  // Neutral
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  static const Color red1 = Colors.red;

  // Cases
  static const Color lightBackground = Color(0xFFF6F4E8);
  static const Color darkBackground = Color(0xFF161717);
  static const Color formField = Colors.white38;
  static const Color searchBar = Color(0xFFF5F5F0);
  static const Color otherUserBubble = Color(0xFFF5F5F0);
  static const Color darkOtherUserBubble = Color(0xFF202C33);
  static const Color lightSkeleton = Color(0xFFe6e9ed);
  static const Color lightSkeletonHighlight = Color(0xFF82B1FF);
  static const Color darkSkeleton = Color(0xFF1E1E1E);
  static const Color darkSkeletonHighlight = Color(0xFF03DAC6);

  // Dark mode surfaces
  static const Color darkFormField = Color(0xFF1F2A30);
  static const Color darkInputBarSurface = Color(0xFF1A1A1A);
  static const Color darkInputBarShadow = Colors.transparent;

  static const Color transparent = Colors.transparent;

  // ------- RANDOM COLOR
  static const senderNameColors = [
    Color(0xFF1565C0), // blue
    Color(0xFF2E7D32), // green
    Color(0xFFC62828), // red
    Color(0xFF6A1B9A), // purple
    Color(0xFFEF6C00), // orange
    Color(0xFF00838F), // teal
    Color(0xFFAD1457), // pink
    Color(0xFF4527A0), // deep purple
  ];

  static Color senderNameColor(String senderId) {
    final index = senderId.hashCode.abs() % senderNameColors.length;
    return senderNameColors[index];
  }
}
