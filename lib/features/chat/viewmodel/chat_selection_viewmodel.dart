import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/user/services/user_service.dart';

class ChatSelectionState {
  final Set<String> selectedIds;

  const ChatSelectionState({this.selectedIds = const {}});

  ChatSelectionState copyWith({required Set<String>? selectedIds}) =>
      ChatSelectionState(selectedIds: selectedIds ?? this.selectedIds);
}

final chatSelectionVM = ChangeNotifierProvider.autoDispose<ChatSelectionVM>(
  (ref) => ChatSelectionVM(ref),
);

class ChatSelectionVM extends BaseNotifier {
  final ChatService _chatService;
  final String? _currentUid;

  ChatSelectionVM(super.ref)
    : _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  ChatSelectionState state = ChatSelectionState();

  // --- GETTER ----------
  bool get isSelecting => state.selectedIds.isNotEmpty;
  int get selectedCount => state.selectedIds.length;

  bool isSelected(String msgId) => state.selectedIds.contains(msgId);

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

  Future<void> deleteForMe(ChatRoomVM chatVM) async {
    await _chatService.deleteMessageForMe(
      uid: _currentUid!,
      chatId: chatVM.chat!.id,
      messageIds: state.selectedIds.toList(),
    );
    clearSelection();
  }

  Future<void> deleteForEveryone(ChatRoomVM chatVM) async {
    await _chatService.deleteMessageForEveryone(
      chatVM.chat!.id,
      state.selectedIds.toList(),
    );
    clearSelection();
  }

  List<MessageModel> getSelectedMessages(ChatRoomVM chatVM) =>
      chatVM.messages.where((m) => state.selectedIds.contains(m.id)).toList();

  void copyToClipboard(ChatRoomVM chatVM) async {
    final selectedMessages =
        chatVM.messages.where((m) => state.selectedIds.contains(m.id)).toList()
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
