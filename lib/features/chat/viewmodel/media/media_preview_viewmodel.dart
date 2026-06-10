import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/media/media_picker_helper.dart';

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
    ref.watch(chatRoomVMProvider(chatId));
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

    final mediaHelper = ref.read(mediaPickerHelperProvider);

    try {
      final uploadedResults = await mediaHelper.uploadFiles(
        files: files,
        type: type,
      );

      if (uploadedResults.isEmpty) return;

      final finalResults = uploadedResults.map((result) {
        final captionText = _captions[result.localPath] ?? '';

        return result.copyWith(caption: captionText);
      }).toList();

      await onSend(finalResults, _captions);
      if (context.mounted) Navigator.pop(context);
    } on DioException catch (e) {
      print('Error send media message: $e');
      notifyListeners();
    } finally {
      _isSending = false;
    }
  }

  Future<void> cropImage(int index) async {
    final file = files[index];
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColorTokens.primary,
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return;

    files[index] = File(cropped.path);
    notifyListeners();
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
