import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';

// Provider
final securityNotifierProvider =
    ChangeNotifierProvider<SecurityNotifier>((ref) => SecurityNotifier.instance);

class SecurityNotifier extends ChangeNotifier {
  // Singleton
  static final SecurityNotifier instance = SecurityNotifier._();
  SecurityNotifier._();
  bool _isCompromised = false;
  String _threatType = '';

  bool get isCompromised => _isCompromised;
  String get threatType => _threatType;

  void attachListeners() {
    final callback = ThreatCallback(
      // ====== CRITICAL ======
      onPrivilegedAccess: () => _handleThreat('rooted'),      // root / jailbreak
      onHooks: () => _handleThreat('hooks'),                  // Frida, Xposed
      onAppIntegrity: () => _handleThreat('tampered'),         // APK modified

      // ====== WARNING ======
      onDebug: () => debugPrint('[Security] Debugger detected'),
      onSimulator: () => debugPrint('[Security] Emulator detected'),
      onDevMode: () => debugPrint('[Security] Developer mode'),
      onUnofficialStore: () => debugPrint('[Security] Unofficial store'),
      onPasscode: () => debugPrint('[Security] No passcode set'),
      onSystemVPN: () => debugPrint('[Security] VPN detected'),
      onObfuscationIssues: () => debugPrint('[Security] Obfuscation missing'),
      onDeviceBinding: () => debugPrint('[Security] Device binding issue'),
      onDeviceID: () => debugPrint('[Security] Device ID issue'),
      onSecureHardwareNotAvailable: () => debugPrint('[Security] No secure hardware'),
      onADBEnabled: () => debugPrint('[Security] ADB enabled'),
      onScreenshot: () => debugPrint('[Security] Screenshot taken'),
      onScreenRecording: () => debugPrint('[Security] Screen recording'),
    );

    Talsec.instance.attachListener(callback);
  }

  void _handleThreat(String type) {
    _threatType = type;
    _isCompromised = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}