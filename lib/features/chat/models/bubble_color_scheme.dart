import 'package:flutter/material.dart';

class BubbleColorScheme {
  final String id;
  final String name;
  final bool isDark;
  final Color sentBubble;
  final Color receivedBubble;

  const BubbleColorScheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.sentBubble,
    required this.receivedBubble,
  });

  static const List<BubbleColorScheme> presets = [
    // Light presets
    BubbleColorScheme(
      id: 'default',
      name: 'Green',
      isDark: false,
      sentBubble: Color(0xFF075E54),
      receivedBubble: Color(0xFFE5F0E5),
    ),
    BubbleColorScheme(
      id: 'blue',
      name: 'Blue',
      isDark: false,
      sentBubble: Color(0xFF233E92),
      receivedBubble: Color(0xFFF5F5F0),
    ),
    BubbleColorScheme(
      id: 'purple',
      name: 'Purple',
      isDark: false,
      sentBubble: Color(0xFF6A1B9A),
      receivedBubble: Color(0xFFF5F0F5),
    ),
    BubbleColorScheme(
      id: 'orange',
      name: 'Orange',
      isDark: false,
      sentBubble: Color(0xFFE65100),
      receivedBubble: Color(0xFFF5EDE5),
    ),
    BubbleColorScheme(
      id: 'teal',
      name: 'Teal',
      isDark: false,
      sentBubble: Color(0xFF00695C),
      receivedBubble: Color(0xFFE0F2F1),
    ),
    BubbleColorScheme(
      id: 'pink',
      name: 'Pink',
      isDark: false,
      sentBubble: Color(0xFFAD1457),
      receivedBubble: Color(0xFFFCE4EC),
    ),

    // Dark presets
    BubbleColorScheme(
      id: 'dark',
      name: 'Dark Mode',
      isDark: true,
      sentBubble: Color(0xFF005C4B),
      receivedBubble: Color(0xFF202C33),
    ),
    BubbleColorScheme(
      id: 'default_freen',
      name: 'Default Green Dark',
      isDark: true,
      sentBubble: Color(0xFF01403A),
      receivedBubble: Color(0xFF1F2A23),
    ),
    BubbleColorScheme(
      id: 'blue_dark',
      name: 'Blue Dark',
      isDark: true,
      sentBubble: Color(0xFF1A2D6B),
      receivedBubble: Color(0xFF202C33),
    ),
    BubbleColorScheme(
      id: 'purple_dark',
      name: 'Purple Dark',
      isDark: true,
      sentBubble: Color(0xFF4A1370),
      receivedBubble: Color(0xFF2A1F2A),
    ),
    BubbleColorScheme(
      id: 'orange_dark',
      name: 'Orange Dark',
      isDark: true,
      sentBubble: Color(0xFFA03C00),
      receivedBubble: Color(0xFF2A211A),
    ),
    BubbleColorScheme(
      id: 'teal_dark',
      name: 'Teal Dark',
      isDark: true,
      sentBubble: Color(0xFF004D43),
      receivedBubble: Color(0xFF1A2826),
    ),
    BubbleColorScheme(
      id: 'pink_dark',
      name: 'Pink Dark',
      isDark: true,
      sentBubble: Color(0xFF7A0E3D),
      receivedBubble: Color(0xFF2A1A1F),
    ),
  ];
}
