import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class ChatRoomVM extends BaseNotifier {
  final ChatService _chatService;
  final SyncService _syncService;
  final CloudMediaService _cloudMediaService;
  final String? _currentUid;
  final String chatId;

  // Subscribing to Firestore
  StreamSubscription? _firestoreSubscription;

  // Pagination
  String? _highlightedMessageId;

  // Typing indicator debounce
  Timer? _typingTimer;
  bool _isTyping = false;

  // Sending message
  bool _isSending = false;

  // Reply Message
  MessageModel? _replyMessage;

  // Upload file
  final _imagePicker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _showMediaPanel = false;

  // audio record
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatService = ref.read(chatServiceProvider),
      _syncService = ref.read(syncServiceProvider),
      _cloudMediaService = ref.read(cloudMediaServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // --- GETTERS ------------------------------
  String? get currentUid => _currentUid;
  bool get isTyping => _isTyping;
  bool get isSending => _isSending;
  MessageModel? get replyMessage => _replyMessage;
  String? get error => _error;
  String? get highlightedMessageId => _highlightedMessageId;
  bool get isUploading => _isUploading;
  bool get showMediaPanel => _showMediaPanel;
  bool get isRecording => _isRecording;

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) {
      _error = 'Not authenticated';
    } else {
      // Turn off notification when in the chatId room
      Future.microtask(() async {
        ref.read(activeChatIdProvider.notifier).state = chatId;
        final syncProvider = ref.read(syncServiceProvider);

        // Fetch from local
        await syncProvider.fetchMessages(chatId);

        // Also listen to Firestore updates
        _firestoreSubscription = await syncProvider
            .streamFirestoreMessages(chatId)
            .listen((_) {
              debugPrint('New messages arrived in Drift local database');
            });
      });

      await _chatService.resetUnreadCount(chatId, _currentUid);
      await _chatService.markChatAsRead(chatId, _currentUid);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentUid == null) return;

    final chat = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (chat == null) {
      _error = 'Getting chat room ready';
      notifyListeners();
      return;
    }

    UserModel? otherUser;
    if (chat.type == 'direct') {
      final otherUid = chat.otherMemberUid(_currentUid);
      otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
    }

    try {
      _isSending = true;
      notifyListeners();
      // clear typing indicator before sending
      await clearTyping();
      final ReplyToModel? replyTo = _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: _replyMessage!.senderName,
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
              mediaUrl: _replyMessage!.allMediaUrls.toString(),
              mediaType: _replyMessage!.type.name,
            )
          : null;

      onCancelReply();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ========================================
  // UPLOAD FILES
  // ========================================
  void toggleMediaPanel(BuildContext context) {
    _showMediaPanel = !_showMediaPanel;
    if (_showMediaPanel) {
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
  }

  // --- Typing Indicator --------------------
  /// Calls this when user types in the text field.
  /// Set debounce for 2 seconds when user type first keystroke.
  void onTextChanged(String text) {
    if (_currentUid == null) return;

    if (text.isNotEmpty || !_isTyping) {
      _isTyping = true;
      _chatService.setTyping(chatId, _currentUid);
    }

    // Reset debounce timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 10), clearTyping);

    if (text.isEmpty) clearTyping();
  }

  Future<void> clearTyping() async {
    if (_currentUid != null && _isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      await _chatService.clearTyping(chatId, _currentUid);
    }
  }

  // ========================================
  // UI HELPERS (Reply & Scroll)
  // ========================================
  void onSwipedMessage(MessageModel message) {
    _replyMessage = message;
    notifyListeners();
  }

  void onCancelReply() {
    _replyMessage = null;
    notifyListeners();
  }

  void highlightMessage(String messageId) {
    ref.read(highlightMessageProvider(chatId).notifier).state = messageId;

    // reset
    Future.delayed(const Duration(seconds: 2), () {
      ref.read(highlightMessageProvider(chatId).notifier).state = null;
    });
  }

  bool isMyMessage(MessageModel message) => message.senderId == _currentUid;
  bool isRepliedMessageMine(String senderId) => _currentUid == senderId;

  void setJumpTarget(int sentAt) {
    ref.read(jumpToTargetProvider(chatId).notifier).state = sentAt;
  }

  void switchToNormalMode() {
    ref.read(jumpToTargetProvider(chatId).notifier).state = null;
  }

  Future<List<UploadResultModel>> uploadFiles({
    required List<File> files,
    required MessageType type,
  }) async {
    try {
      final results = await Future.wait(
        files.map(
          (f) => _cloudMediaService.uploadFile(file: f, mediaType: type),
        ),
      );

      return results.whereType<UploadResultModel>().toList();
    } on CloudinaryUploadException catch (e) {
      showToast(e.message);
    } catch (e) {
      showToast('Error uploading. Please try again.');
    }

    return [];
  }

  Future<List<File>> pickMultipleVideos({required bool fromCamera}) async {
    final pickedList = await _imagePicker.pickMultiVideo(
      limit: 5,
      maxDuration: Duration(seconds: 180),
    );
    if (pickedList.isEmpty) return [];

    final files = await Future.wait(
      pickedList.map((xfile) => _toTempFile(xfile)),
    );

    return files.whereType<File>().toList();
  }

  Future<File?> pickImage({required bool fromCamera}) async {
    final picked = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return null;
    return _toTempFile(picked);
  }

  Future<List<File>> pickMultipleImages() async {
    final pickedList = await _imagePicker.pickMultiImage(
      imageQuality: 70,
      limit: 5,
    );
    if (pickedList.isEmpty) return [];

    final files = await Future.wait(
      pickedList.map((xfile) => _toTempFile(xfile)),
    );

    return files.whereType<File>().toList();
  }

  Future<File?> _toTempFile(XFile picked) async {
    try {
      final bytes = await picked.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${picked.name}');
      await tempFile.writeAsBytes(bytes);
      return tempFile;
    } catch (e) {
      print('Failed to convert file: $e');
      return null;
    }
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

    final files = await Future.wait(
      result.xFiles.map((xfile) => _toTempFile(xfile)),
    );

    return files.whereType<File>().toList();
  }

  Future<void> sendMediaMessage({
    required List<UploadResultModel> files,
  }) async {
    try {
      _isUploading = true;
      notifyListeners();

      final filesWithCaption = files
          .where((f) => f.caption != null && f.caption != '')
          .toList();
      final allUrls = files.map((f) => f.url).toList();

      /// Only create within single bubble if only one caption was found.
      if (filesWithCaption.length <= 1) {
        final singleCaption = filesWithCaption.isNotEmpty
            ? filesWithCaption.first.caption!
            : '';

        await _sendSingleBubble(
          urls: allUrls,
          caption: singleCaption,
          file: files.first,
        );
      } else {
        for (final file in files) {
          await _sendSingleBubble(
            urls: [file.url],
            caption: file.caption ?? '',
            file: file,
          );
        }
      }
    } on CloudinaryUploadException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to upload file';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> _sendSingleBubble({
    required List<dynamic> urls,
    required String caption,
    required UploadResultModel file,
  }) async {
    if (_currentUid == null) return;

    final chat = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (chat == null) {
      _error = 'Getting chat room ready';
      notifyListeners();
      return;
    }

    UserModel? otherUser;
    if (chat.type == 'direct') {
      final otherUid = chat.otherMemberUid(_currentUid);
      otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
    }

    final uploadedFile = File(file.fileName);

    try {
      _isSending = true;
      notifyListeners();

      await _syncService.sendMediaMessage(
        chatRoomId: chatId,
        senderName: chat.displayName(_currentUid),
        memberUids: chat.members,
        caption: file.caption,
        files: [uploadedFile],
        type: file.messageType,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: _replyMessage!.senderName,
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
              mediaUrl: _replyMessage!.mediaUrls?.firstOrNull,
              mediaType: _replyMessage!.type.name,
            )
          : null,
      );

      onCancelReply();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // =================================
  // AUDIO RECORDING
  // =================================
  Future<void> startRecording() async {
    try {
      // Ketuk pintu: Minta izin mic
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return;
      }

      await _audioRecorder.start(
        const RecordConfig(),
        path: 'my_temp_audio.m4a',
      );

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      print('Error in recording audio: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      _isRecording = false;
      notifyListeners();

      if (path != null) {
        print("Done recording, File in: $path");
      }
    } catch (e) {
      print("Stop recording failed: $e");
    }
  }

  String getCloudinaryThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    return videoUrl.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
  }

  MessageType _resolveMessageType(List<UploadResultModel> results) {
    final types = results.map((r) => r.messageType).toSet();
    if (types.length == 1) return types.first; // semua sama
    return MessageType.media; // campuran
  }

  String _mediaNotificationText(MessageType type, String caption) {
    if (caption.isNotEmpty) return caption;
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📎 File';
      default:
        return '';
    }
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    ref.read(activeChatIdProvider.notifier).state = null;
    _firestoreSubscription?.cancel();
    clearTyping();
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

// ==========================
// PROVIDER
// ==========================
// Use .family because each chat room will have its own vm
final chatRoomVMProvider = ChangeNotifierProvider.autoDispose
    .family<ChatRoomVM, String>(
      (ref, chatId) => ChatRoomVM(ref, chatId: chatId),
    );

final jumpToTargetProvider = StateProvider.autoDispose.family<int?, String>(
  (ref, chatId) => null,
);

final chatMessagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, chatId) {
      final db = ref.watch(messageDatabaseProvider);

      final targetSentAt = ref.watch(jumpToTargetProvider(chatId));

      Stream<List<Message>> localStream;

      if (targetSentAt != null) {
        localStream = db.watchMessagesAround(
          chatId,
          targetSentAt: targetSentAt,
          limit: 50,
        );
      } else {
        // No target sent means nothing for us to jump
        final uid = ref.read(currentUidProvider);
        localStream = db.watchMessages(chatId, uid!, limit: 50);
      }

      return localStream.map((localMsgs) {
        debugPrint(
          '🕵️‍♂️ [DEBUG CHAT] Local Stream terpanggil! ChatID: $chatId',
        );
        debugPrint(
          '🕵️‍♂️ [DEBUG CHAT] Jumlah pesan dari SQLite (Drift): ${localMsgs.length}',
        );

        return localMsgs.map((m) => MessageModel(
            id: m.id,
            senderId: m.senderId,
            senderName: m.senderName,
            text: m.textContent,
            type: MessageType.values.firstWhere(
              (e) => e.name.toLowerCase() == m.type.toLowerCase(),
              orElse: () => MessageType.text,
            ),
            sentAt: DateTime.fromMillisecondsSinceEpoch(m.sentAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(m.updatedAt),
            isDeleted: m.isDeleted,
            deletedFor: m.deletedFor,

            syncStatus: m.syncStatus,

            // Decode array jika ada
            mediaUrls: m.mediaUrls != null
                ? List<String>.from(jsonDecode(m.mediaUrls!))
                : null,
            fileName: m.fileName,

            // Mapping Reply
            replyTo: m.replyToId != null
                ? ReplyToModel(
                    messageId: m.replyToId!,
                    senderId: '', // Sesuaikan jika lu butuh
                    senderName: m.replyToSenderName ?? '',
                    text: m.replyToText ?? '',
                    sentAt: DateTime.now(),
                    mediaType: m.replyToMediaType,
                    mediaUrl: m.replyToMediaUrl,
                  )
                : null,
          ),
        ).toList();
      });
    });

final chatMetadataStreamProvider = StreamProvider.autoDispose
    .family<ChatModel?, String>((ref, chatId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.streamChat(chatId);
    });

final otherUserStreamProvider = StreamProvider.autoDispose
    .family<UserModel?, String>((ref, otherUserId) {
      final userService = ref.watch(userServiceProvider);
      return userService.streamUser(otherUserId);
    });

final highlightMessageProvider = StateProvider.autoDispose
    .family<String?, String>((ref, chatId) => null);
