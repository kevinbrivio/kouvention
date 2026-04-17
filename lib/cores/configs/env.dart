import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env.staging')
abstract class EnvStaging {
  @EnviedField(varName: 'SHOW_BANNER')
  static const bool showBanner = _EnvStaging.showBanner;
}

@Envied(path: '.env.prod')
abstract class EnvProd {
  @EnviedField(varName: 'SHOW_BANNER')
  static const bool showBanner = _EnvProd.showBanner;
}
