import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.read(prefsServiceProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final PrefsService _prefs;
  ThemeModeNotifier(this._prefs) : super(_prefs.getThemeMode());

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    _prefs.setThemeMode(mode);
  }
}
