import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';
import 'package:kouvention/cores/constants/custom_theme.dart';
import 'package:kouvention/cores/router/auth_notifier.dart';
import 'package:kouvention/cores/router/prefs_guard.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/cores/router/router_guard.dart';
import 'package:kouvention/cores/services/dio_handler.dart';
import 'package:kouvention/cores/widgets/flavor_banner.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/notification/services/notification_handler.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:kouvention/features/shared/viewmodel/security_notifier.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';
import 'package:kouvention/features/shared/views/device_blocked_view.dart';
import 'package:kouvention/features/user/viewmodel/presence_notifier.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      await ScreenUtil.ensureScreenSize();

      // FLAVOR SETUP
      const flavor = String.fromEnvironment('ENV');
      setupConfig(flavor);
      // Check for rooted / jailbroken device
      await SecurityNotifier.instance.checkDeviceSecurity();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final authService = AuthService();
      await authService.initialize(
        clientId: '',
        serverClientId: flavor == 'staging'
            ? EnvStaging.googleServerClientId
            : EnvProd.googleServerClientId,
      );

      // Background handler for notification
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
        debugPrint('[main] firebaseBackgroundHandler registered');
      } catch (e, s) {
        debugPrint(
          '[main] firebaseBackgroundHandler registration FAILED: $e\n$s',
        );
      }

      // Pass all uncuaught errors from Flutter to Crashlytics
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Pass all uncaught async error to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // SHARED PREFS
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PrefsService(prefs);

      final onboardingSeen = await prefsService.hasSeenOnboarding();
      final privacyPolicySeen = await prefsService.hasAcceptedPrivacyPolicy();

      final prefsGuard = PrefsGuard(
        onboardingSeen: onboardingSeen,
        privacyPolicySeen: privacyPolicySeen,
      );

      final authNotifier = AuthNotifier(authService);

      final routerGuard = RouterGuard(
        authNotifier: authNotifier,
        prefsGuard: prefsGuard,
      );

      await setupRouter(
        initialRouter: '/',
        authService: authService,
        routerGuard: routerGuard,
      );

      // Register DIO Handler
      DioHandler.setup();

      runApp(
        ProviderScope(
          overrides: [
            prefsServiceProvider.overrideWithValue(prefsService),
            authServiceProvider.overrideWithValue(authService),
            prefsGuardProvider.overrideWithValue(prefsGuard),
          ],
          child: const KouventionApp(),
        ),
      );
    },
    (error, stack) {
      print(error);
      print(stack);
    },
  );
}

void setupConfig(String flavor) {
  FlavorConfig(
    flavor: convertToFlavorEnum(flavor),
    values: flavor == 'staging'
        ? FlavorValues(showBanner: EnvStaging.showBanner)
        : FlavorValues(showBanner: EnvProd.showBanner),
  );
}

class KouventionApp extends ConsumerStatefulWidget {
  const KouventionApp({super.key});

  @override
  ConsumerState<KouventionApp> createState() => _KouventionAppState();
}

class _KouventionAppState extends ConsumerState<KouventionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[App] initState — reading providers...');
    ref.read(
      presenceNotifierProvider,
    ); // listen to presence notifier to check user presence throughout the use
    try {
      ref.read(notificationHandlerProvider);
      debugPrint('[App] notificationHandlerProvider read OK');
    } catch (e, s) {
      debugPrint('[App] notificationHandlerProvider read FAILED: $e\n$s');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: const Size(375, 768),
      minTextAdapt: true,
    );

    final security = ref.watch(securityNotifierProvider);
    ref.listen(networkAutoSyncProvider, (_, __) {});

    if (security.isCompromised) {
      return MaterialApp(
        home: DeviceBlockedView(
          threatType: security.threatType,
          onExit: () => SystemNavigator.pop(),
        ),
      );
    }
    return OKToast(
      child: MaterialApp.router(
        builder: (_, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(boldText: true),
          child: FlavorBanner(child: child!),
        ),
        title: 'Kouvention',
        debugShowCheckedModeBanner: FlavorConfig.showBanner(),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(themeModeProvider),
        routerConfig: router,
      ),
    );
  }
}
