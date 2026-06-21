import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => MediaPickerService(),
);

class MediaPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<XFile?> pickImage({bool fromGallery = true}) async {
    final picked = await _imagePicker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return null;

    return picked;
  }

  Future<List<XFile>> pickImages({int limit = 5}) async {
    final picked = await _imagePicker.pickMultiImage(
      limit: limit,
      imageQuality: 70,
    );
    if (picked.isEmpty) return [];

    return picked.whereType<XFile>().toList();
  }

  Future<XFile?> pickVideo({
    bool fromGallery = true,
    Duration maxDuration = const Duration(seconds: 30),
  }) => _imagePicker.pickVideo(
    source: fromGallery ? ImageSource.gallery : ImageSource.camera,
    maxDuration: maxDuration,
  );

  Future<List<XFile>> pickMultipleVideos({int limit = 5}) async {
    final picked = await _imagePicker.pickMultiVideo(limit: limit);
    if (picked.isEmpty) return [];

    return picked.whereType<XFile>().toList();
  }
}
