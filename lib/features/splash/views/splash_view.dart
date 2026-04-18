import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/widgets/floating_widget.dart';
import 'package:kouvention/features/splash/viewmodel/splash_viewmodel.dart';
import 'package:kouvention/features/splash/widgets/splash_logo.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:kouvention/cores/router/router_constants.dart';
// import 'package:video_player/video_player.dart';

class SplashView extends ConsumerWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splash = ref.watch(splashVM);

    splash.markOnboardingSeen();
    splash.acceptPrivacyPolicy();

    ref.listen<SplashVM>(splashVM, (prev, curr) {
      if (curr.shouldShowOnboarding) {
        context.go('/onboarding');
      } else if (curr.isLoggedIn) {
        context.go('/home');
      } else if (curr.shouldShowPrivacyPolicy) {
        context.go('/privacy-policy');
      } else {
        context.go('/login');
      }
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
// class SplashView extends ConsumerStatefulWidget {
//   SplashView({super.key});

//   @override
//   ConsumerState<ConsumerStatefulWidget> createState() => _SplashViewState();
// }

// class _SplashViewState extends ConsumerState<SplashView> {
//   late VideoPlayerController _videoController;
//   bool _isVideoInitialized = false;
//   bool _hasNavigated = false;

//   initState() {
//     super.initState();
//     // _initializeVideo();
//   }

//   Future<void> _initializeVideo() async {
//     try {
//       _videoController = VideoPlayerController.asset(
//         videoPlayerOptions: VideoPlayerOptions(
//           mixWithOthers: true,
//           allowBackgroundPlayback: true,
//         ),
//       );

//       await _videoController.initialize();
//       await _videoController.setVolume(0);
//       _videoController.setLooping(true);

//       if (!mounted) return;

//       setState(() {
//         _isVideoInitialized = true;
//       });

//       await _videoController.play();

//       _videoController.addListener(_videoListener);
//     } catch (e) {
//       print('Error initializing video: $e');
//       // Handle error, e.g., show a fallback image or message
//     }
//   }

//   void _videoListener() {
//     if (!mounted || _hasNavigated) return;

//     if (_videoController.value.position >= _videoController.value.duration) {
//       _navigateToHome();
//     }
//   }

//   void _navigateToHome() {
//     if (_hasNavigated || !mounted) return;

//     _hasNavigated = true;
//     context.go(RouterRoutes.home.path);
//   }

//   void dispose() {
//     _videoController.removeListener(_videoListener);
//     _videoController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // TODO: implement build
//     throw UnimplementedError();
//   }
// }
