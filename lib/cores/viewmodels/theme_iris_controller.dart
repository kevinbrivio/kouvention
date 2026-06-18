import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';

final themeIrisControllerProvider =
    StateNotifierProvider<ThemeIrisController, ui.Image?>(
  ThemeIrisController.new,
);

final themeSnapshotKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

class ThemeIrisController extends StateNotifier<ui.Image?> {
  final Ref _ref;
  ThemeIrisController(this._ref) : super(null);

  Future<void> changeTheme(
    BuildContext context,
    ThemeMode mode, {
    required GlobalKey snapshotKey,
  }) async {
    if (state != null) return;

    final currentMode = _ref.read(themeModeProvider);
    if (currentMode == mode) return;

    try {
      final boundary = snapshotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        state = image;
      }
    } catch (_) {}

    _ref.read(themeModeProvider.notifier).setThemeMode(mode);
  }

  void clear() => state = null;
}
