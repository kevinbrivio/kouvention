import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/chat/services/media/media_picker_service.dart';

final mediaPickerHelperProvider = Provider<MediaPickerHelper>(
  (ref) => MediaPickerHelper(ref),
);

class MediaPickerHelper extends BaseNotifier {
  MediaPickerHelper(super.ref);

  @override
  FutureOr<void> init() {}

  // Future<List<UploadResultModel>> uploadFiles({
  //   required List<File> files,
  //   required MessageType type,
  // }) async {
  //   try {
  //     final results = await Future.wait(
  //       files.map((f) => _mediaService.uploadFile(file: f, mediaType: type)),
  //     );

  //     return results.whereType<UploadResultModel>().toList();
  //   } on CloudinaryUploadException catch (e) {
  //     showToast(e.message);
  //   } catch (e) {
  //     showToast('Error uploading. Please try again.');
  //   }

  //   return [];
  // }

  Future<XFile?> pickImage({required bool fromGallery}) async {
    final service = ref.read(mediaPickerServiceProvider);
    try {
      final file = await service.pickImage(fromGallery: fromGallery);
      return file;
    } catch (e) {
      debugPrint('VM pick single image error: $e');
      return null;
    }
  }

  Future<List<XFile>> pickMultipleImages() async {
    final service = ref.read(mediaPickerServiceProvider);
    try {
      final files = await service.pickImages(limit: 5);
      return files;
    } catch (e) {
      debugPrint('VM pickMultipleImages error: $e');
      return [];
    }
  }

  // Future<File?> pickVideo({required bool fromCamera}) async {
  //   final picked = await _imagePicker.pickVideo(
  //     source: fromCamera ? ImageSource.camera : ImageSource.gallery,
  //     maxDuration: const Duration(minutes: 3),
  //   );
  //   if (picked == null) return null;
  //   return File(picked.path);
  // }

  // Future<File?> pickFile() async {
  //   final result = await FilePicker.pickFiles(
  //     type: FileType.custom,
  //     allowedExtensions: [
  //       'pdf',
  //       'doc',
  //       'docx',
  //       'xls',
  //       'xlsx',
  //       'ppt',
  //       'pptx',
  //       'mp3',
  //       'm4a',
  //       'wav',
  //     ],
  //     withData: false, // Don't save the data into memory
  //     withReadStream: false,
  //   );

  //   if (result == null || result.files.isEmpty) return null;

  //   final path = result.files.first.path;
  //   if (path == null) return null;

  //   return File(path);
  // }
}
