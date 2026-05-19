import 'package:freerasp/freerasp.dart';
import 'package:kouvention/cores/configs/env.dart';

class SecurityService {
  bool isProd;

  SecurityService({required this.isProd});

  static Future<void> initialize({required bool isProd}) async {
    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.example.kouvention',
        signingCertHashes: [isProd ? EnvProd.sha256 : EnvStaging.sha256],
        supportedStores: ['com.android.vending'],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.example.kouvention'],
        teamId: '[PLACEHOLDER]', // Change to iOS teamID
      ),
      watcherMail: 'kenkenku6@gmail.com',
      isProd: isProd,
    );

    await Talsec.instance.start(config);
  }
}
