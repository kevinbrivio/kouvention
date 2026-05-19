import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF4490ed);
  static const Color primary2 = Color(0xFF233e92);
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
  static const Color formField = Colors.white38;
  static const Color searchBar = Color(0xFFF5F5F0);
  static const Color otherUserBubble = Color(0xFFF5F5F0);

  static const Color transparent = Colors.transparent;
  
  // ------- RANDOM COLOR
  static const senderNameColors  = [
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
