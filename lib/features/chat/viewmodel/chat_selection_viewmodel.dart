import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

class ChatSelectionState {
  final Set<String> selectedIds;

  const ChatSelectionState({this.selectedIds = const {}});

  ChatSelectionState copyWith({required Set<String>? selectedIds}) =>
      ChatSelectionState(selectedIds: selectedIds ?? this.selectedIds);
}

final chatSelectionVM = ChangeNotifierProvider.autoDispose
    .family<ChatSelectionVM, String>(
      (ref, chatId) => ChatSelectionVM(ref, chatId: chatId),
    );

class ChatSelectionVM extends BaseNotifier {
  final SyncService _syncService;
  final String? _currentUid;
  final String chatId;

  ChatSelectionVM(super.ref, {required this.chatId})
    : _syncService = ref.read(syncServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  ChatSelectionState state = ChatSelectionState();

  // --- GETTER ----------
  bool get isSelecting => state.selectedIds.isNotEmpty;
  int get selectedCount => state.selectedIds.length;

  bool isSelected(String msgId) => state.selectedIds.contains(msgId);

  List<MessageModel> get _currentMessages =>
      ref.read(chatMessagesStreamProvider(chatId)).value ?? [];

  void startSelection(String msgId) {
    state = state.copyWith(selectedIds: {msgId});
    notifyListeners();
  }

  void toggleSelection(String msgId) {
    final updated = Set<String>.from(state.selectedIds);

    if (updated.contains(msgId)) {
      updated.remove(msgId);
    } else {
      updated.add(msgId);
    }

    // if the bucket is empty, exit automatically
    state = state.copyWith(selectedIds: updated);
    notifyListeners();
  }

  void clearSelection() {
    state = const ChatSelectionState();
    notifyListeners();
  }

  Future<void> deleteForMe() async {
    if (_currentUid == null || state.selectedIds.isEmpty) return;

    await _syncService.deleteMessageForMe(
      chatId: chatId,
      messageIds: state.selectedIds.toList(),
    );
    clearSelection();
  }

  Future<void> deleteForEveryone() async {
    if (state.selectedIds.isEmpty) return;

    await _syncService.deleteMessageForEveryone(
      chatId: chatId,
      messageIds: state.selectedIds.toList(),
    );
    clearSelection();
  }

  List<MessageModel> getSelectedMessages() =>
      _currentMessages.where((m) => state.selectedIds.contains(m.id)).toList();

  void copyToClipboard() async {
    if (state.selectedIds.isEmpty) return;

    final selectedMessages = getSelectedMessages()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    String clipboardText;

    if (selectedMessages.length == 1) {
      clipboardText = selectedMessages.first.text;
    } else {
      clipboardText = selectedMessages
          .map((m) {
            final date = DateTimeHelper.formatDateMonthClock(m.sentAt);
            final sender = m.senderName;
            return '[$date] $sender: ${m.text}';
          })
          .join('\n');
    }

    await Clipboard.setData(ClipboardData(text: clipboardText));

    clearSelection();
  }

  @override
  FutureOr<void> init() async {
    if (_currentUid == null) return;
  }
}
