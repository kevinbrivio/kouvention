import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final getIt = GetIt.instance;

class DioHandler {
  final Dio dio;
  static String get _cloudName => FlavorConfig.instance?.name == 'staging' 
    ? EnvStaging.cloudinaryCloudName 
    : EnvProd.cloudinaryCloudName;

  DioHandler._internal()
    : dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.cloudinary.com/v1_1/$_cloudName',
          connectTimeout: Duration(seconds: 5),
          sendTimeout: Duration(seconds: 3),
        ),
      ) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
  }

  static void setup() {
    getIt.registerLazySingleton(() => DioHandler._internal());
  }
}
