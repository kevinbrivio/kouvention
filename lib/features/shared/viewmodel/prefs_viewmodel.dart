import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final prefsVM = ChangeNotifierProvider<PrefsVM>((ref) => PrefsVM(ref));

class PrefsVM extends BaseNotifier {
  PrefsVM(super.ref) {
    _prefsService = ref.read(prefsServiceProvider);
  }

  late final PrefsService _prefsService;

  bool hasSeenOnboarding = false;
  bool hasAcceptedPrivacyPolicy = false;

  @override
  Future<void> init() async {
    await loadPrefs();
  }

  Future<void> loadPrefs() async {
    hasSeenOnboarding = await _prefsService.hasSeenOnboarding();
    hasAcceptedPrivacyPolicy = await _prefsService.hasAcceptedPrivacyPolicy();
  }

  Future<void> markOnboardingSeen() async {
    if (await _prefsService.setHasSeenOnboarding(true)) {
      hasSeenOnboarding = true;
      notifyListeners();
    }
  }

  Future<void> acceptPrivacyPolicy() async {
    if (await _prefsService.setHasAcceptedPrivacyPolicy(true)) {
      hasAcceptedPrivacyPolicy = true;
      notifyListeners();
    }
  }
}
