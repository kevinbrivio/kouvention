import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';

final bubbleSchemeProvider =
    StateNotifierProvider<BubbleSchemeNotifier, BubbleColorScheme>((ref) {
      final prefs = ref.read(prefsServiceProvider);
      final themeMode = ref.watch(themeModeProvider);
      return BubbleSchemeNotifier(prefs)..load(themeMode);
    });

class BubbleSchemeNotifier extends StateNotifier<BubbleColorScheme> {
  final PrefsService _prefs;

  BubbleSchemeNotifier(this._prefs) : super(BubbleColorScheme.presets.first);

  void load(ThemeMode mode) {
    final isDark = _isDarkFor(mode);
    final id = _prefs.getBubbleSchemeId(isDark: isDark);

    state = BubbleColorScheme.presets.firstWhere(
      (s) => s.id == id && s.isDark == isDark,
      orElse: () => BubbleColorScheme.presets.firstWhere(
        (s) => s.isDark == isDark,
        orElse: () => BubbleColorScheme.presets.first,
      ),
    );
  }

  void select(BubbleColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    state = scheme;
    _prefs.setBubbleSchemeId(scheme.id, isDark: isDark);
  }

  static bool _isDarkFor(ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }
}
