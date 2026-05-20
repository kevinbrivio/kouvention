import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';
import 'package:kouvention/cores/services/dio_handler.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());

class MediaService {
  final Dio _dio = getIt<DioHandler>().dio;
  final String _uploadPreset = FlavorConfig.instance?.name == 'staging'
      ? EnvStaging.cloudinaryUploadPreset
      : EnvProd.cloudinaryUploadPreset;

  // Upload file to Cloudinary
  Future<UploadResultModel?> uploadFile({
    required File file,
    required MessageType mediaType,
  }) async {
    // Upload to Cloudinary to get the URL
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': _uploadPreset,
      });

      final response = await _dio.post(
        '/${mediaType.name}/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return UploadResultModel.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      print('Upload error: ${e.response?.data}');
    }

    return null;
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}
