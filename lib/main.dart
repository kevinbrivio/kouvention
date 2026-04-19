import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';
import 'package:kouvention/cores/router/router.dart';
import 'package:kouvention/cores/widgets/flavor_banner.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ));

      await ScreenUtil.ensureScreenSize();

      // TODO: SETUP FLAVOR CONFIG

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

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

      const flavor = String.fromEnvironment('ENV');
      setupConfig(flavor);

      await setupRouter(initialRouter: '/');

      runApp(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
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

class KouventionApp extends StatefulWidget {
  const KouventionApp({super.key});

  @override
  State<KouventionApp> createState() => _KouventionAppState();
}

class _KouventionAppState extends State<KouventionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    return OKToast(
      child: MaterialApp.router(
        builder: (_, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(boldText: false),
          child: FlavorBanner(child: child!),
        ),
        title: 'Kouvention',
        debugShowCheckedModeBanner: FlavorConfig.showBanner(),
        theme: ThemeData(primaryColor: FlavorConfig.instance!.color),
        // theme: ,
        routerConfig: router,
      ),
    );
  }
}
