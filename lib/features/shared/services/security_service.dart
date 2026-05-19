import 'package:freerasp/freerasp.dart';
import 'package:kouvention/cores/configs/env.dart';

class SecurityService {
  bool isProd;

  SecurityService({required this.isProd});

  static Future<void> initialize({required bool isProd}) async {
    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.example.kouvention',
        signingCertHashes: [isProd ? EnvProd.SHA256 : EnvStaging.SHA256], // TODO: GANTI KE ENV
        supportedStores: ['com.android.vending'],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.example.kouvention'],
        teamId: '',
      ),
      watcherMail: 'kenkenku6@gmail.com',
      isProd: isProd,
    );

    await Talsec.instance.start(config);
  }
}
