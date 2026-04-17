import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  final SharedPreferences _prefs;

  const PrefsService(this._prefs);

  // --- KEYS
  static const String _onboardingKey = 'has_seen_onboarding';
  static const String _privacyPolicyKey = 'has_accepted_privacy_policy';

  // --- ONBOARDING
  Future<bool> hasSeenOnboarding() async {
    return _prefs.getBool(_onboardingKey) ?? false;
  }

  Future<bool> setHasSeenOnboarding(bool value) async {
    return _prefs.setBool(_onboardingKey, value);
  }

  // --- PRIVACY POLICY
  Future<bool> hasAcceptedPrivacyPolicy() async {
    return _prefs.getBool(_privacyPolicyKey) ?? false;
  }

  Future<bool> setHasAcceptedPrivacyPolicy(bool value) async {
    return _prefs.setBool(_privacyPolicyKey, value);
  }

}