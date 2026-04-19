import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/features/splash/viewmodel/splash_viewmodel.dart';
import 'package:kouvention/features/splash/widgets/splash_logo.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    ref.read(splashVM);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(splashVM);

    ref.listen<SplashVM>(splashVM, (prev, curr) {
      final nextRoute = curr.nextRoute;

      if (_hasNavigated || !curr.isInitialized || nextRoute == null) {
        return;
      }

      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(nextRoute);
        }
      });
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.backdrop],
            stops: [0.6, 0.9],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: FloatingWidget(child: SplashLogo())),
      ),
    );
  }
}
