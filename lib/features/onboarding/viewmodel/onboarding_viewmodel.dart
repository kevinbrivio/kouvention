import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

final onboardingVM = ChangeNotifierProvider.autoDispose(OnboardingVM.new);

class OnboardingVM extends BaseNotifier {
  OnboardingVM(super.ref);

  static const totalPages = 3;

  late final PrefsService _prefsService = ref.read(prefsServiceProvider);

  late int currentPage;
  late CarouselSliderController controller;

  @override
  FutureOr<void> init() {
    currentPage = 0;
    controller = CarouselSliderController();
  }

  void syncPage(int index) {
    if (currentPage == index) return;
    currentPage = index;
    notifyListeners();
  }

  Future<void> goToPage(int index) async {
    if (index < 0 || index > totalPages) return;
    await controller.animateToPage(index);
  }

  Future<void> nextPage() => goToPage(currentPage + 1);
  Future<void> backPage() => goToPage(currentPage - 1);

  Future<void> goToPrivacyPolicy() async {
    final context = ctx;
    await _prefsService.setHasSeenOnboarding(true);
    if (!context.mounted) return;
    context.go(RouterRoutes.privacyPolicy.path);
  }
}
