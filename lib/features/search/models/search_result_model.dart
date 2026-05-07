class SearchResultModel {
  final String messageId;
  final String chatRoomId;
  final String senderId;
  final String messageText; // matched searched
  final String senderName;
  final DateTime sentAt;

  SearchResultModel({
    required this.messageId,
    required this.chatRoomId,
    required this.senderId,
    required this.messageText,
    required this.senderName,
    required this.sentAt,
  });

  
}
