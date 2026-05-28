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
import 'package:kouvention/features/chat/services/media_service.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';

class MediaPreviewVM extends BaseNotifier {
  final String chatId;
  static int maxFiles = 5;
  List<File> files;
  int _currentIndex = 0;
  final MessageType type;
  final Future<void> Function(
    List<UploadResultModel> result,
    Map<String, String> caption,
  )
  onSend;

  bool _isSending = false;
  final Map<String, String> _captions = {};
  File get currentFile => files[_currentIndex];
  int get currentIndex => _currentIndex;
  int get totalFiles => files.length;

  MediaPreviewVM(
    super.ref, {
    required this.files,
    required this.type,
    required this.onSend,
    required this.chatId,
  });

  bool get isSending => _isSending;
  String captionFor(String filePath) => _captions[filePath] ?? '';

  @override
  FutureOr<void> init() {
    ref.watch(chatRoomVM(chatId));
  }

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

  void onCaptionChanged(String filePath, String value) {
    _captions[filePath] = value;
    notifyListeners();
  }

  Future<void> send(BuildContext context) async {
    _isSending = true;
    notifyListeners();

    print('======= CAPTIONS =======');
    print(_captions);
    print('Files count: ${files.length}');
    _captions.forEach((path, caption) {
      print('File: $path → Caption: $caption');
    });
    print('========================');

    final mediaService = MediaService();

    try {
      final rawResults = await Future.wait(
        files.map(
          (file) => mediaService.uploadFile(file: file, mediaType: type),
        ),
      );

      final results = <UploadResultModel>[];
      for (int i = 0; i < files.length; i++) {
        final result = rawResults[i];
        if (result == null) continue;

        final caption = _captions[files[i].path] ?? '';
        results.add(result.copyWith(caption: caption));
      }
      if (results.isEmpty) return;

      await onSend(results, _captions);
      if (context.mounted) Navigator.pop(context);
    } on DioException catch (e) {
      print('Error send media message: $e');
      notifyListeners();
    } finally {
      _isSending = false;
    }
  }

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
        chatId: args.chatId,
        onSend: args.onSend,
      ),
    );

class MediaPreviewArgs {
  final List<File> files;
  final MessageType mediaType;
  final String chatId;
  final Future<void> Function(List<UploadResultModel>, Map<String, String>)
  onSend;

  const MediaPreviewArgs({
    required this.files,
    required this.mediaType,
    required this.chatId,
    required this.onSend,
  });
}
