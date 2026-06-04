import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final bubbleSchemeProvider = StateNotifierProvider<BubbleSchemeNotifier, BubbleColorScheme>((ref) {
  final prefs = ref.read(prefsServiceProvider);
  return BubbleSchemeNotifier(prefs);
});

class BubbleSchemeNotifier extends StateNotifier<BubbleColorScheme> {
  final PrefsService _prefs;

  BubbleSchemeNotifier(this._prefs)
      : super(BubbleColorScheme.presets.first) {
    _loadSaved();
  }

  void _loadSaved() {
    final id = _prefs.getBubbleSchemeId();
    final saved = BubbleColorScheme.presets.firstWhere(
      (s) => s.id == id,
      orElse: () => BubbleColorScheme.presets.first,
    );
    state = saved;
  }

  void select(BubbleColorScheme scheme) {
    state = scheme;
    _prefs.setBubbleSchemeId(scheme.id);
  }
}
