import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/models/message_model.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';

enum MessageStatus { sending, sent, read }

extension MessageStatusExtension on MessageModel {
  MessageStatus getUIStatus(ChatModel? chat, String currentUid) {
    if (this.syncStatus == SyncStatus.pending) return MessageStatus.sending;

    if (chat != null) {
      final otherUid = chat.otherMemberUid(currentUid);
      final otherReadAt = chat.lastReadAt[otherUid];

      if (otherReadAt != null) {
        if (this.sentAt.isBefore(otherReadAt) ||
            this.sentAt.isAtSameMomentAs(otherReadAt))
          return MessageStatus.sent;
      }
    }

    return MessageStatus.sent;
  }
}
