import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

enum MessageStatus { sending, sent, read }

extension MessageStatusExtension on MessageModel {
  MessageStatus getUIStatus(ChatModel? chat, String currentUid) {
    if (syncStatus == SyncStatus.pending) return MessageStatus.sending;

    // Read receipts only apply to direct chats (one other member).
    if (chat != null && chat.isDirect) {
      final otherUid = chat.otherMemberUid(currentUid);
      final otherReadAt = chat.lastReadAt[otherUid];

      if (otherReadAt != null) {
        if (sentAt.isBefore(otherReadAt) ||
            sentAt.isAtSameMomentAs(otherReadAt)) {
          return MessageStatus.sent;
        }
      }
    }

    return MessageStatus.sent;
  }
}
