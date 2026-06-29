import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_profile_provider.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/models/reply_to_model.dart';
import 'package:kouvention/features/chat/models/sticker_model.dart';
import 'package:kouvention/features/chat/models/upload_result_model.dart';
import 'package:kouvention/features/chat/repositories/chat_repository.dart';
import 'package:kouvention/features/chat/repositories/message_repository.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/audio_manager.dart';
import 'package:kouvention/features/notification/viewmodel/active_chat_id_provider.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:snackify/enums/snack_enums.dart';
import 'package:snackify/snackify.dart';
import 'package:kouvention/cores/utils/log.dart';

/// Voice recording state machine (§3.1 of recap).
///
/// Transitions:
///   idle → recording → locked → reviewing → sending → idle
///     ↓                 ↓
///   (tap)            (discard)
enum RecordingState { idle, recording, locked, reviewing, sending }

class ChatRoomVM extends BaseNotifier {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  final CloudMediaService _cloudMediaService;
  final String? _currentUid;
  final String chatId;

  // Subscribing to Firestore
  StreamSubscription? _firestoreSubscription;

  // Pagination
  static const messagePaginationThreshold = 100;
  bool _hasMoreMessages = true;
  bool _isLoadingOlder = false;

  String? _highlightedMessageId;

  // Typing indicator debounce
  Timer? _typingTimer;
  Timer? _typingDebounce;
  static const _typingDebounceWindow = Duration(seconds: 2);
  bool _isTyping = false;

  // Sending message
  bool _isSending = false;

  // Reply Message
  MessageModel? _replyMessage;

  // Upload file
  bool _isUploading = false;
  bool _showMediaPanel = false;

  // Stickers
  bool _showStickerPanel = false;

  // audio record
  final AudioRecorder _audioRecorder = AudioRecorder();
  RecordingState _recordingState = RecordingState.idle;
  String? _recordingPath;
  int _recordingDuration = 0;
  final List<double> _amplitudeSamples = [];
  Timer? _recordingTimer;
  StreamSubscription? _amplitudeSub;

  String? _error;

  ChatRoomVM(super.ref, {required this.chatId})
    : _chatRepository = ref.read(chatRepositoryProvider),
      _messageRepository = ref.read(messageRepositoryProvider),
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
  bool get showStickerPanel => _showStickerPanel;
  RecordingState get recordingState => _recordingState;
  int get recordingDuration => _recordingDuration;
  List<double> get recordingAmplitudeSamples => _amplitudeSamples;
  String? get recordingPath => _recordingPath;
  bool get hasMoreMessges => _hasMoreMessages;
  bool get isLoadingOlder => _isLoadingOlder;

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) {
      _error = 'Not authenticated';
      return;
    }

    // Turn off notification when in the chatId room
    Future.microtask(() async {
      ref.read(activeChatIdProvider.notifier).state = chatId;

      // 1. Fetch missed messages for this chat (bounded, idempotent).
      await _messageRepository.fetchMissedMessages(chatId);

      // 🔄 Force chatMessagesStreamProvider to re-read from Drift.
      ref.read(chatRoomRefreshProvider(chatId).notifier).state++;
      notifyListeners();

      // 2. Mirror chat metadata into Drift so the chat list reflects
      //    the latest unread / typing / lastMessage fields.
      try {
        await _chatRepository.getChat(chatId);
      } catch (e) {
        wLog('Chat metadata sync skipped ($e)');
      }

      // 3. Attach the realtime listener so incoming messages land in
      //    Drift and reconcile any locally-pending row by messageId.
      _firestoreSubscription = _messageRepository
          .watchActiveChatRealtime(chatId)
          .listen((_) {
            dLog('New messages arrived in Drift local database');
          });

      // 4. Non-critical: reset unread + advance lastReadAt.
      try {
        await _messageRepository.markChatAsRead(chatId, _currentUid);
      } catch (e) {
        // Implicit retry: opening the chat again writes a fresh
        // lastReadAt + reset unreadCount. networkAutoSyncProvider
        // covers pending messages, not read receipts.
        wLog('Offline: unread/read update skipped ($e)');
      }

      // 5. Update lastOpenedAt so the LRU eviction ranks this chat as
      //    recently used and preserves it from eviction. Non-critical.
      try {
        await ref.read(messageDatabaseProvider).updateLastOpenedAt(chatId);
      } catch (e) {
        wLog('lastOpenedAt update skipped ($e)');
      }
    });
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _currentUid == null) return;

    final chat = await _resolveChatForSend();
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
              mediaUrl: _replyMessage!.allMediaUrls.firstOrNull,
              mediaType: _replyMessage!.type.name,
            )
          : null;

      await _messageRepository.sendTextMessage(
        chatRoomId: chat.id,
        textContent: text,
        senderName: resolveDisplayName(
          chat: chat,
          currentUid: _currentUid,
          resolver: ref.read(chatRoomProfileResolverProvider(chatId)),
        ),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: replyTo,
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

  // ========================================
  // SYNC MESSAGES & PAGINATION
  // ========================================
  /// Loads the next older page of messages for this chat.
  Future<void> loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreMessages) return;

    try {
      _isLoadingOlder = true;
      notifyListeners();

      // 1. Get chat metadata
      final db = ref.read(messageDatabaseProvider);
      final chat = await db.getChatById(chatId);

      // 2. Validate from chat, if there is still data from Firestore
      if (!(chat?.hasMoreOlderRemote ?? false)) {
        _hasMoreMessages = false;
        return;
      }

      // 3. Fetch data from Firestore
      final result = await _messageRepository.fetchOlderMessages(
        chatId,
        limit: 50,
        maxPages: 1,
      );
      final refreshed = await db.getChatById(chatId);
      if (result.messages == 0 || (!(refreshed?.hasMoreOlderRemote ?? false))) {
        _hasMoreMessages = false;
      }
    } catch (e) {
      _hasMoreMessages = true;
      eLog('===== loadOlderMessages failed: $e\n');
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  // ========================================
  // UPLOAD FILES
  // ========================================
  void toggleMediaPanel(BuildContext context) {
    _showMediaPanel = !_showMediaPanel;
    if (_showMediaPanel) {
      _showStickerPanel = false;
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
  }

  void closeMediaPanel() {
    _showMediaPanel = false;
    notifyListeners();
  }

  void toggleStickerPanel(BuildContext context) {
    _showStickerPanel = !_showStickerPanel;
    if (_showStickerPanel) {
      _showMediaPanel = false;
      FocusScope.of(context).unfocus();
    }
    notifyListeners();
  }

  void closeStickerPanel() {
    _showStickerPanel = false;
    notifyListeners();
  }

  void dismissPanels() {
    if (_showMediaPanel || _showStickerPanel) {
      _showMediaPanel = false;
      _showStickerPanel = false;
      notifyListeners();
    }
  }

  Future<void> sendSticker(StickerModel sticker) async {
    if (_currentUid == null) return;

    final chat = await _resolveChatForSend();
    if (chat == null) return;

    try {
      _isSending = true;
      notifyListeners();

      final replyTo = _replyMessage != null
          ? ReplyToModel(
              messageId: _replyMessage!.id,
              senderId: _replyMessage!.senderId,
              senderName: _replyMessage!.senderName,
              text: _replyMessage!.text,
              sentAt: _replyMessage!.sentAt,
              mediaUrl: _replyMessage!.allMediaUrls.firstOrNull,
              mediaType: _replyMessage!.type.name,
            )
          : null;

      UserModel? otherUser;
      if (chat.type == 'direct') {
        final otherUid = chat.otherMemberUid(_currentUid);
        otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
      }

      await _messageRepository.sendSticker(
        chatRoomId: chatId,
        stickerUrl: sticker.url,
        senderName: resolveDisplayName(
          chat: chat,
          currentUid: _currentUid,
          resolver: ref.read(chatRoomProfileResolverProvider(chatId)),
        ),
        memberUids: chat.members,
        otherUserFcmTokens: otherUser?.fcmTokens,
        replyTo: replyTo,
      );
    } catch (e, s) {
      eLog('Error sending sticker: $e $s');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // --- Typing Indicator --------------------
  void onTextChanged(String text) {
    if (_currentUid == null) return;

    if (text.isEmpty) {
      clearTyping();
      return;
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(_typingDebounceWindow, () {
      if (_isTyping) return;
      _isTyping = true;
      _messageRepository.setTyping(chatId, _currentUid);
    });

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 10), clearTyping);
  }

  Future<void> clearTyping() async {
    if (_isTyping && _currentUid != null) {
      _isTyping = false;
      _typingTimer?.cancel();
      _typingDebounce?.cancel();
      await _messageRepository.clearTyping(chatId, _currentUid);
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

  void clearHighlight() {
    ref.read(highlightMessageProvider(chatId).notifier).state = null;
  }

  bool isMyMessage(MessageModel message) => message.senderId == _currentUid;
  bool isRepliedMessageMine(String senderId) => _currentUid == senderId;

  void setJumpTarget(int sentAt) {
    ref.read(jumpToTargetProvider(chatId).notifier).state = sentAt;
  }

  /// Clear jump target and highlight. Call when the user explicitly returns to
  /// latest messages (scroll-to-bottom, close button, etc.).
  void switchToNormalMode() {
    ref.read(jumpToTargetProvider(chatId).notifier).state = null;
    ref.read(highlightMessageProvider(chatId).notifier).state = null;
  }

  Future<void> fetchMessagesAround(DateTime sentAt) async {
    await _messageRepository.fetchMessagesAround(chatId, sentAt);
  }

  Future<void> sendMediaMessage({
    required List<UploadResultModel> files,
  }) async {
    try {
      _isUploading = true;
      notifyListeners();

      final captionedFiles = files
          .where((f) => f.caption != null && f.caption!.isNotEmpty)
          .toList();

      final mediaCaptions = files.map((f) => f.caption ?? '').toList();

      if (captionedFiles.length <= 1) {
        await _sendSingleBubble(
          caption: captionedFiles.isNotEmpty
              ? captionedFiles.first.caption!
              : '',
          files: files,
          mediaCaptions: mediaCaptions,
        );
      } else {
        for (final file in files) {
          try {
            await _sendSingleBubble(
              caption: file.caption ?? '',
              files: [file],
              mediaCaptions: [file.caption ?? ''],
            );
          } catch (_) {
            break;
          }
        }
      }

      onCancelReply();
    } catch (e) {
      _error = 'Failed to send media message';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> _sendSingleBubble({
    required String caption,
    required List<UploadResultModel> files,
    List<String>? mediaCaptions,
  }) async {
    if (_currentUid == null) return;
    if (files.isEmpty) return;
    if (files.any((f) => f.localPath == null)) return;

    final chat = await _resolveChatForSend();
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

    final captions =
        mediaCaptions ?? files.map((f) => f.caption ?? '').toList();

    try {
      await _messageRepository.sendMediaMessageDirect(
        chatRoomId: chatId,
        senderName: resolveDisplayName(
          chat: chat,
          currentUid: _currentUid,
          resolver: ref.read(chatRoomProfileResolverProvider(chatId)),
        ),
        memberUids: chat.members,
        caption: caption,
        uploadResults: files,
        mediaCaptions: captions,
        type: files.first.messageType,
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
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =================================
  // VOICE RECORDING (state machine)
  // =================================

  /// Start recording audio from microphone.
  /// Transitions: idle → recording.
  Future<void> startRecording(
    BuildContext context, {
    required bool startsLocked,
  }) async {
    if (_recordingState != RecordingState.idle) return;

    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      Snackify.show(
        context: context,
        type: SnackType.error,
        title: Text('Enable microphone access on settings'),
        action: TextButton(
          onPressed: openAppSettings,
          child: Text('Open Settings'),
        ),
      );
      return;
    }

    // Generate temp file path
    final tempDir = await Directory.systemTemp.createTemp('kou_audio_');
    final supported = await _audioRecorder.isEncoderSupported(
      AudioEncoder.opus,
    );
    final encoder = supported ? AudioEncoder.opus : AudioEncoder.aacLc;
    final ext = supported ? 'opus' : 'm4a';
    final tempPath =
        '${tempDir.path}${DateTime.now().millisecondsSinceEpoch}.$ext';
    _recordingPath = tempPath;

    try {
      await _audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 32000,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
        ),
        path: tempPath,
      );

      _recordingState = startsLocked
          ? RecordingState.locked
          : RecordingState.recording;
      _recordingDuration = 0;
      _amplitudeSamples.clear();

      // Duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration++;
        notifyListeners();
      });

      // Amplitude subscription
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            const double minDb = -60.0;
            const double maxDb = 0.0;

            final normalized = ((amp.current - minDb) / (maxDb - minDb)).clamp(
              0.0,
              1.0,
            );

            _amplitudeSamples.add(normalized);
            // Cap at 1 hour (36000 samples @ 10/sec)
            if (_amplitudeSamples.length > 36000) {
              _amplitudeSub?.cancel();
            }
            notifyListeners();
          });
    } catch (e) {
      eLog('Error starting recording: $e');
      _resetRecording();
    }
  }

  /// Lock the recording (finger slid up). Continues recording.
  /// Transitions: recording → locked.
  void lockRecording() {
    if (_recordingState != RecordingState.recording) return;
    _recordingState = RecordingState.locked;
    notifyListeners();
  }

  /// Cancel/discard recording. Silently deletes temp file.
  /// Transitions: recording/locked → idle.
  Future<void> cancelRecording() async {
    if (_recordingState == RecordingState.idle) return;
    if (_recordingState == RecordingState.reviewing ||
        _recordingState == RecordingState.sending)
      return;

    await _audioRecorder.cancel();
    _deleteTempFile();
    _resetRecording();
    notifyListeners();
  }

  /// Stop recording and enter review state.
  /// Transitions: locked → reviewing.
  Future<void> stopRecording() async {
    if (_recordingState != RecordingState.locked) return;

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        _recordingPath = path;
      }

      _recordingTimer?.cancel();
      _amplitudeSub?.cancel();

      _recordingState = RecordingState.reviewing;
      notifyListeners();
    } catch (e) {
      eLog('Error stopping recording: $e');
      _resetRecording();
    }
  }

  /// Pause recording and enter review state (tap path).
  /// Transitions: locked → reviewing.
  Future<void> pauseRecording() async {
    if (_recordingState != RecordingState.locked) return;

    try {
      await _audioRecorder.stop();

      _recordingTimer?.cancel();
      _recordingTimer = null;
      _amplitudeSub?.cancel();
      _amplitudeSub = null;

      _recordingState = RecordingState.reviewing;
      notifyListeners();
    } catch (e) {
      eLog('Error pausing recording: $e');
      _resetRecording();
    }
  }

  /// Transitions: locked/reviewing → sending → idle.
  Future<void> sendRecordedAudio() async {
    if (_recordingState != RecordingState.reviewing &&
        _recordingState != RecordingState.locked)
      return;
    if (_recordingPath == null || _currentUid == null) return;

    // If still recording (locked), stop the recorder first
    if (_recordingState == RecordingState.locked) {
      final path = await _audioRecorder.stop();
      if (path != null) _recordingPath = path;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
    }

    // Update the recording state to sent
    _recordingState = RecordingState.sending;
    _isSending = true;
    notifyListeners();

    // Stop any playback
    AudioManager.instance.stop();

    try {
      final file = File(_recordingPath!);

      // Upload to Cloudinary
      final uploadResult = await _cloudMediaService.uploadFile(
        file: file,
        mediaType: MessageType.audio,
      );

      if (uploadResult == null) throw Exception('Audio upload failed');

      // Get chat metadata
      final chat = await _resolveChatForSend();
      if (chat == null) throw Exception('Chat not ready');

      // Enrich with local path for traceability
      final enriched = uploadResult.copyWith(
        localPath: _recordingPath,
        mediaDuration: _recordingDuration,
      );

      // Determine other user for FCM if direct chat
      UserModel? otherUser;
      if (chat.type == 'direct') {
        final otherUid = chat.otherMemberUid(_currentUid);
        otherUser = ref.read(otherUserStreamProvider(otherUid)).value;
      }

      await _messageRepository.sendMediaMessageDirect(
        chatRoomId: chatId,
        senderName: resolveDisplayName(
          chat: chat,
          currentUid: _currentUid,
          resolver: ref.read(chatRoomProfileResolverProvider(chatId)),
        ),
        memberUids: chat.members,
        caption: 'Audio message',
        uploadResults: [enriched],
        type: MessageType.audio,
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
      await file.delete();
      _resetRecording();
    } catch (e) {
      eLog('Error sending recorded audio: $e');
      _error = 'Failed to send audio. Tap to retry.';
      _recordingState = RecordingState.reviewing;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<ChatModel?> _resolveChatForSend() async {
    final cached = ref.read(chatMetadataStreamProvider(chatId)).value;
    if (cached != null) return cached;

    try {
      return await _chatRepository.getChat(chatId);
    } catch (e) {
      eLog('resolveChatForSend failed for $chatId: $e');
      return null;
    }
  }

  /// Discard recorded audio. Deletes temp file.
  void discardRecording() {
    if (_recordingState != RecordingState.reviewing &&
        _recordingState != RecordingState.locked)
      return;
    _deleteTempFile();
    _resetRecording();
    notifyListeners();
  }

  // ── Helpers ──

  void _resetRecording() {
    try {
      _audioRecorder.stop();
    } catch (_) {}
    _recordingState = RecordingState.idle;
    _recordingPath = null;
    _recordingDuration = 0;
    _amplitudeSamples.clear();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  void _deleteTempFile() {
    if (_recordingPath != null) {
      try {
        File(_recordingPath!).delete();
      } catch (_) {}
      _recordingPath = null;
    }
  }

  String getCloudinaryThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    return videoUrl.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
  }

  // --- CleanUp ----------------------------------
  @override
  void dispose() {
    ref.read(activeChatIdProvider.notifier).state = null;
    _firestoreSubscription?.cancel();
    clearTyping();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _deleteTempFile();
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

/// Increment this to force `chatMessagesStreamProvider` to re-create its
/// Drift subscription (e.g. after the initial fetch in `init()` completes).
/// Drift's `watch()` stream often misses the re-emission when a `batch()`
/// upsert happens shortly after subscription — re-subscribing re-reads the
/// now-populated cache immediately.
final chatRoomRefreshProvider = StateProvider.autoDispose.family<int, String>(
  (ref, chatId) => 0,
);

final chatMessagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, chatId) {
      final db = ref.watch(messageDatabaseProvider);
      // Watch refresh trigger — re-creates stream when init fetches data.
      ref.watch(chatRoomRefreshProvider(chatId));

      final uid = ref.read(currentUidProvider);
      final localStream = db.watchAllCachedMessages(chatId, uid!);

      return localStream.map((localMsgs) {
        dLog('Drift messages in chat room: ${localMsgs.length}');
        return localMsgs
            .map(
              (m) => MessageModel(
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
                mediaUrls: m.mediaUrls ?? [],
                mediaCaptions: m.mediaCaptions,
                fileSizeBytes: m.fileSizeBytes,
                fileName: m.fileName,
                mimeType: m.mimeType ?? '',
                mediaDuration: m.mediaDuration,

                // Mapping Reply
                replyTo: m.replyToId != null
                    ? ReplyToModel(
                        messageId: m.replyToId!,
                        senderId: m.replyToSenderId ?? '',
                        senderName: m.replyToSenderName ?? '',
                        text: m.replyToText ?? '',
                        sentAt: m.replyToSentAt != null
                            ? DateTime.fromMillisecondsSinceEpoch(
                                m.replyToSentAt!,
                              )
                            : DateTime.fromMillisecondsSinceEpoch(m.sentAt),
                        mediaType: m.replyToMediaType,
                        mediaUrl: m.replyToMediaUrl,
                      )
                    : null,
              ),
            )
            .toList();
      });
    });

final chatMetadataStreamProvider = StreamProvider.autoDispose
    .family<ChatModel?, String>((ref, chatId) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchChat(chatId);
    });

/// Debug-only: streams the raw Drift [Chat] row so the 4-field sync
/// state can be rendered live in the chat room's debug overlay.
/// Hidden behind [kDebugMode] in the view; this provider is always
/// available but cheap to subscribe to.
final chatRowDebugStreamProvider = StreamProvider.autoDispose
    .family<Chat?, String>((ref, chatId) {
      final db = ref.watch(messageDatabaseProvider);
      return db.watchChatRow(chatId);
    });

final otherUserStreamProvider = StreamProvider.autoDispose
    .family<UserModel?, String>((ref, otherUserId) {
      final userService = ref.watch(userServiceProvider);
      return userService.streamUser(otherUserId);
    });

final highlightMessageProvider = StateProvider.autoDispose
    .family<String?, String>((ref, chatId) => null);
