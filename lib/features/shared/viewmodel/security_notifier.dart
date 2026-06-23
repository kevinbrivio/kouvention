import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/shared/services/security_service.dart';

// Provider
final securityNotifierProvider = ChangeNotifierProvider<SecurityNotifier>(
  (ref) => SecurityNotifier.instance,
);

class SecurityNotifier extends ChangeNotifier {
  // Singleton
  static final SecurityNotifier instance = SecurityNotifier._();
  SecurityNotifier._();
  bool _isCompromised = false;
  String _threatType = '';

  bool get isCompromised => _isCompromised;
  String get threatType => _threatType;

  Future<void> checkDeviceSecurity() async {
    final rooted = await SecurityService.isDeviceRooted();
    if (rooted) {
      _isCompromised = true;
      _threatType = 'rooted';
      notifyListeners();
    }
  }
}
