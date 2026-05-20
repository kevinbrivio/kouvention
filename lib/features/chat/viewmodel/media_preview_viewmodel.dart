import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';

class MediaPreviewVM extends BaseNotifier {
  static int maxFiles = 5;
  List<File> files;
  int _currentIndex = 0;
  final MessageType type;
  final void Function(List<UploadResultModel> result, String? caption) onSend;

  bool _isSending = false;
  String? _caption;
  File get currentFile => files[_currentIndex];
  int get currentIndex => _currentIndex;
  int get totalFiles => files.length;

  MediaPreviewVM(
    super.ref, {
    required this.files,
    required this.type,
    required this.onSend,
  });

  bool get isSending => _isSending;
  String? get caption => _caption;

  @override
  FutureOr<void> init() {}

  void selectFile(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void goToIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void removeFile(int index) {
    files.removeAt(index);
    if (_currentIndex >= files.length) {
      _currentIndex = files.length - 1;
    }
    notifyListeners();
  }

  void addFile(File newFile) {
    if (files.length < maxFiles) {
      files.add(newFile);
    }
    notifyListeners();
  }

  void onCaptionChanged(String value) {
    _caption = value.trim().isEmpty ? null : value.trim();
  }

  // Future<void> send(BuildContext context) async {
  //   _isSending = true;
  //   notifyListeners();

  //   final mediaService = MediaService();

  //   try {

  //     final result = await mediaService.uploadFile(file: file, mediaType: type);

  //     if (result == null) return;

  //     onSend(result, _caption);
  //     if (context.mounted) Navigator.pop(context);
  //   } on DioException catch (e) {
  //     print('Error send media message: $e');
  //   } finally {
  //     _isSending = false;
  //     notifyListeners();
  //   }
  // }

  Future<File?> cropImage(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: AppColors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return null;

    notifyListeners();
    return File(cropped.path);
  }
}

final mediaPreviewProvider = ChangeNotifierProvider.autoDispose
    .family<MediaPreviewVM, MediaPreviewArgs>(
      (ref, args) => MediaPreviewVM(
        ref,
        files: args.files,
        type: args.mediaType,
        onSend: args.onSend,
      ),
    );

class MediaPreviewArgs {
  final List<File> files;
  final MessageType mediaType;
  final void Function(List<UploadResultModel>, String?) onSend;

  const MediaPreviewArgs({
    required this.files,
    required this.mediaType,
    required this.onSend,
  });
}
