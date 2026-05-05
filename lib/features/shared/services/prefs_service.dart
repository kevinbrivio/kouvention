  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  
  final prefsServiceProvider = Provider<PrefsService>((ref) {
    throw UnimplementedError(
      'PrefsService must be initialized in main.dart using ProviderScope.overrideWithValue',
    );
  });
  
  class PrefsService {
    final SharedPreferences _prefs;
  
    const PrefsService(this._prefs);
  
    // --- KEYS
    static const String _onboardingKey = 'has_seen_onboarding';
    static const String _privacyPolicyKey = 'has_accepted_privacy_policy';
    static const String _fcmTokenKey = 'fcm_tokens';
  
    // --- ONBOARDING
    Future<bool> hasSeenOnboarding() async =>
        _prefs.getBool(_onboardingKey) ?? false;
  
    Future<bool> setHasSeenOnboarding(bool value) async =>
        _prefs.setBool(_onboardingKey, value);
  
    // --- PRIVACY POLICY
    Future<bool> hasAcceptedPrivacyPolicy() async =>
        _prefs.getBool(_privacyPolicyKey) ?? false;
  
    Future<bool> setHasAcceptedPrivacyPolicy(bool value) async =>
        _prefs.setBool(_privacyPolicyKey, value);

    // --- FCM
    String? getFcmToken() => _prefs.getString(_fcmTokenKey);
    
    Future<bool> setFcmToken(String val) async =>
        _prefs.setString(_fcmTokenKey, val);
    
    Future<bool> removeFcmToken() async =>
        _prefs.remove(_fcmTokenKey);
  }
