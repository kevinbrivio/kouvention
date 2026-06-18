import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';
import 'package:kouvention/cores/services/dio_handler.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';

final cloudMediaServiceProvider = Provider<CloudMediaService>(
  (ref) => CloudMediaService(),
);

class CloudMediaService {
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
      final mediaName = (mediaType == MessageType.file || mediaType == MessageType.audio) 
        ? 'auto' 
        : mediaType.name;
      
      final response = await _dio.post(
        '/$mediaName/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (mediaType == MessageType.audio) {
          data['secure_url'] = (data['secure_url'] as String).replaceFirst(
            '/upload/',
            '/upload/f_m4a,br_32k,ar_16000/',
          );
        }

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
