import 'package:flutter/material.dart';

class BubbleColorScheme {
  final String id;
  final String name;
  final Color sentBubble;
  final Color receivedBubble;

  const BubbleColorScheme({
    required this.id,
    required this.name,
    required this.sentBubble,
    required this.receivedBubble,
  });

  static const List<BubbleColorScheme> presets = [
    BubbleColorScheme(
      id: 'default',
      name: 'Default Blue',
      sentBubble: Color(0xFF233E92),
      receivedBubble: Color(0xFFF5F5F0),
    ),
    BubbleColorScheme(
      id: 'green',
      name: 'Green',
      sentBubble: Color(0xFF075E54),
      receivedBubble: Color(0xFFE5F0E5),
    ),
    BubbleColorScheme(
      id: 'purple',
      name: 'Purple',
      sentBubble: Color(0xFF6A1B9A),
      receivedBubble: Color(0xFFF5F0F5),
    ),
    BubbleColorScheme(
      id: 'orange',
      name: 'Orange',
      sentBubble: Color(0xFFE65100),
      receivedBubble: Color(0xFFF5EDE5),
    ),
    BubbleColorScheme(
      id: 'teal',
      name: 'Teal',
      sentBubble: Color(0xFF00695C),
      receivedBubble: Color(0xFFE0F2F1),
    ),
    BubbleColorScheme(
      id: 'pink',
      name: 'Pink',
      sentBubble: Color(0xFFAD1457),
      receivedBubble: Color(0xFFFCE4EC),
    ),
    BubbleColorScheme(
      id: 'dark',
      name: 'Dark Mode',
      sentBubble: Color(0xFF005C4B),
      receivedBubble: Color(0xFF202C33),
    ),
  ];
}
