import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WallpaperService {
  static const _subdir = 'wallpapers';
  static const _filePrefix = 'wp_';
  static const _fileExt = '.jpg';

  final ImagePicker _picker = ImagePicker();

  Future<File?> pickAndCrop() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Wallpaper',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: AppColors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Wallpaper',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null;

    return saveToDocs(File(cropped.path));
  }

  Future<File> saveToDocs(File source) async {
    final dir = await _ensureDir();
    final dest = File(
      p.join(dir.path, '${_filePrefix}${_timestamp()}$_fileExt'),
    );
    return source.copy(dest.path);
  }

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    return file.delete().then((_) => true).catchError((_) => false);
  }

  Future<Directory> _ensureDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
}
