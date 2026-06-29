import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env.staging')
abstract class EnvStaging {
  @EnviedField(varName: 'SHOW_BANNER')
  static const bool showBanner = _EnvStaging.showBanner;
  @EnviedField(varName: 'GOOGLE_SERVER_CLIENT_ID')
  static const String googleServerClientId = _EnvStaging.googleServerClientId;
  @EnviedField(varName: 'CLOUDINARY_CLOUD_NAME')
  static const String cloudinaryCloudName = _EnvStaging.cloudinaryCloudName;
  @EnviedField(varName: 'CLOUDINARY_UPLOAD_PRESET')
  static const String cloudinaryUploadPreset =
      _EnvStaging.cloudinaryUploadPreset;
  @EnviedField(varName: 'sha256')
  static const String sha256 = _EnvStaging.sha256;
}

@Envied(path: '.env.prod')
abstract class EnvProd {
  @EnviedField(varName: 'SHOW_BANNER')
  static const bool showBanner = _EnvProd.showBanner;
  @EnviedField(varName: 'GOOGLE_SERVER_CLIENT_ID')
  static const String googleServerClientId = _EnvProd.googleServerClientId;
  @EnviedField(varName: 'CLOUDINARY_CLOUD_NAME')
  static const String cloudinaryCloudName = _EnvProd.cloudinaryCloudName;
  @EnviedField(varName: 'CLOUDINARY_UPLOAD_PRESET')
  static const String cloudinaryUploadPreset = _EnvProd.cloudinaryUploadPreset;
  @EnviedField(varName: 'sha256')
  static const String sha256 = _EnvProd.sha256;
}
