import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/configs/env.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:mime/mime.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>(
  (ref) => CloudinaryService(),
);

class CloudinaryService {
  // Max: 10B
  static const int maxFileSize = 10 * 1024 * 1024;

  // Allowed MIME type prefixes
  static const _allowedTypes = [
    'image/', // jpg, png, gif, webp
    'video/', // mp4, mov, webm
    'audio/', // mp3, m4a, wav
    'application/pdf',
    'application/msword', // .doc
    'application/vnd.openxmlformats-officedocument', // .docx, .xlsx, .pptx
  ];

  late final CloudinaryPublic _cloudinary;

  CloudinaryService() {
    _cloudinary = CloudinaryPublic(
      // TODO: Change to Prod
      EnvStaging.cloudinaryCloudName,
      EnvStaging.cloudinaryUploadPreset,
      cache: false,
    );
  }

  /// Upload single file to Cloudinary
  /// Throws [CloudinaryUploadException] if fail
  Future<UploadResultModel> uploadFile(File file) async {
    // 1. Validate file
    _validateFile(file);

    // 2. Detect file info
    final fileName = file.uri.pathSegments.last;
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final messageType = _mimeToMessageType(mimeType);
    final fileSizeBytes = await file.length();

    // 3. Upload
    final resourceType = _getResourceType(messageType);

    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: resourceType,
        folder: 'chat_media',
      ),
    );

    return UploadResultModel(
      url: response.secureUrl,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      messageType: messageType,
    );
  }

  void _validateFile(File file) {
    if (!file.existsSync()) {
      throw CloudinaryUploadException('No file was found');
    }

    final size = file.lengthSync();
    if (size > maxFileSize) {
      final sizeMB = (size / (1024 * 1024)).toStringAsFixed(2);
      throw CloudinaryUploadException(
        'File was too big: ($sizeMB MB). Max is 10MB',
      );
    }

    final mimeType = lookupMimeType(file.uri.pathSegments.last);
    if (mimeType == null || !_isAllowedType(mimeType)) {
      throw CloudinaryUploadException('File type is not supported');
    }
  }

  bool _isAllowedType(String mimeType) =>
      _allowedTypes.any((t) => mimeType.startsWith(t));

  MessageType _mimeToMessageType(String mimeType) {
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('audio/')) return MessageType.audio;
    if (mimeType.startsWith('video/')) return MessageType.video;

    return MessageType.file;
  }

  // There are only 3 types in CloudinaryResourceType.
  // Image, Video, Raw(audio, etc)
  CloudinaryResourceType _getResourceType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return CloudinaryResourceType.Image;
      case MessageType.video:
        return CloudinaryResourceType.Video;
      default:
        return CloudinaryResourceType.Raw;
    }
  }
}

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}
