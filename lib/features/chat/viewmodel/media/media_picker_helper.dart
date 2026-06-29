import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/utils/log.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:kouvention/features/chat/services/media/media_picker_service.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final mediaPickerHelperProvider = Provider<MediaPickerHelper>(
  (ref) => MediaPickerHelper(ref),
);

class MediaPickerHelper extends BaseNotifier {
  MediaPickerHelper(super.ref);

  final ImagePicker _imagePicker = ImagePicker();
  final CloudMediaService _cloudMediaService = CloudMediaService();

  @override
  FutureOr<void> init() {}

  Future<List<UploadResultModel>> uploadFiles({
    required List<File> files,
    required MessageType type,
  }) async {
    try {
      final results = await Future.wait(
        files.map((f) async {
          final result = await _cloudMediaService.uploadFile(
            file: f,
            mediaType: type,
          );

          if (result != null) {
            return result.copyWith(localPath: f.path);
          }
          return null;
        }),
      );

      return results.whereType<UploadResultModel>().toList();
    } on CloudinaryUploadException catch (e) {
      showToast(e.message);
    } catch (e) {
      showToast('Error uploading. Please try again.');
    }

    return [];
  }

  Future<File?> pickImage({required bool fromGallery}) async {
    final service = ref.read(mediaPickerServiceProvider);
    try {
      final xfile = await service.pickImage(fromGallery: fromGallery);
      if (xfile == null) return null;
      return await _toTempFile(xfile);
    } catch (e) {
      eLog('VM pick single image error: $e');
      return null;
    }
  }

  Future<List<File>> pickMultipleImages() async {
    final service = ref.read(mediaPickerServiceProvider);
    try {
      final xfiles = await service.pickImages(limit: 5);
      final files = await Future.wait(xfiles.map(_toTempFile));
      return files.whereType<File>().toList();
    } catch (e) {
      eLog('VM pickMultipleImages error: $e');
      return [];
    }
  }

  Future<List<File>> pickMultipleVideos({required bool fromCamera}) async {
    final service = ref.read(mediaPickerServiceProvider);
    try {
      final xfiles = await service.pickMultipleVideos(limit: 5);
      final files = await Future.wait(xfiles.map(_toTempFile));
      return files.whereType<File>().toList();
    } catch (e) {
      eLog('VM pickMultipleVideos error: $e');
      return [];
    }
  }

  Future<File?> _toTempFile(XFile picked) async {
    if (picked.path.isEmpty) return null;
    final source = File(picked.path);
    if (!await source.exists()) return null;

    final dir = await getTemporaryDirectory();
    final dest = File(
      p.join(
        dir.path,
        'kou_media_${DateTime.now().millisecondsSinceEpoch}_'
        '${p.basename(picked.path)}',
      ),
    );
    return source.copy(dest.path);
  }

  Future<File?> pickVideo({required bool fromCamera}) async {
    final picked = await _imagePicker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<File?> pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['mp3', 'm4a'],
      withData: false,
      withReadStream: false,
    );

    if (result == null) return null;
    return File(result.files.first.path!);
  }

  Future<File?> pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'mp3',
        'm4a',
        'wav',
      ],
      withData: false,
      withReadStream: false,
    );

    if (result == null) return null;
    return File(result.files.first.path!);
  }

  Future<List<File>> pickMultipleFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'mp3',
        'm4a',
        'wav',
      ],
      withData: false, // Don't save the data into memory
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final path = result.files.first.path;
    if (path == null) return [];

    final files = await Future.wait(result.xFiles.map(_toTempFile));

    return files.whereType<File>().toList();
  }
}
