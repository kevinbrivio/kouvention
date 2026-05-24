import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => MediaPickerService(),
);

class MediaPickerService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<XFile?> pickImage({ bool fromGallery = true }) async {
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
}
