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
      sentBubble: Color(0xFFd9fdd3),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'pearl',
      name: 'Pearl',
      isDark: false,
      sentBubble: Color(0xFFe8e0ff),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'orange',
      name: 'Orange',
      isDark: false,
      sentBubble: Color(0xFFfee2d8),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'blue',
      name: 'Blue',
      isDark: false,
      sentBubble: Color(0xFFd2e8fe),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'pink',
      name: 'Pink',
      isDark: false,
      sentBubble: Color(0xFFfdced9),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'yellow',
      name: 'Yellow',
      isDark: false,
      sentBubble: Color(0xFFfdf8af),
      receivedBubble: Color(0xFFf9f9f9),
    ),
    BubbleColorScheme(
      id: 'april',
      name: 'April',
      isDark: false,
      sentBubble: Color(0xFFc1a886),
      receivedBubble: Color(0xFFf9f9f9),
    ),

    // Dark presets
    BubbleColorScheme(
      id: 'dark',
      name: 'Dark Mode',
      isDark: true,
      sentBubble: Color(0xFF144d37),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'pearl_dark',
      name: 'Dark Pearl',
      isDark: true,
      sentBubble: Color(0xFF2c2a5b),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'orange_dark',
      name: 'Orange Dark',
      isDark: true,
      sentBubble: Color(0xFF4c2c24),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'blue_dark',
      name: 'Blue Dark',
      isDark: true,
      sentBubble: Color(0xFF05264a),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'pink_dark',
      name: 'Pink Dark',
      isDark: true,
      sentBubble: Color(0xFF531323),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'yellow_dark',
      name: 'Yellow Dark',
      isDark: true,
      sentBubble: Color(0xFF5c5100),
      receivedBubble: Color(0xFF232525),
    ),
    BubbleColorScheme(
      id: 'april_dark',
      name: 'April Dark',
      isDark: true,
      sentBubble: Color(0xFF7b654c),
      receivedBubble: Color(0xFF232525),
    ),
  ];
}
