import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class BaseNotifier extends ChangeNotifier {
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _isInitializedDone = false;
  bool _showOverlay = false;

  final Ref ref;

  BaseNotifier(this.ref) {
    _init();
  }

  FutureOr<void> init();

  void _init() async {
    isLoading = true;
    await init();
    _isInitializedDone = true;
    isLoading = false;
  }

  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitializedDone;
  bool get showOverlay => _showOverlay;

  // Setters
  set isLoading(bool value) {
    _isLoading = value;
    scheduleMicrotask(() {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  set showOverlay(bool value) {
    _showOverlay = value;
    scheduleMicrotask(() {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }
}
