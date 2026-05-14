class ReplyToModel {
  final String messageId;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime sentAt;

  ReplyToModel({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
  });

  factory ReplyToModel.fromMap(Map<String, dynamic> map) => ReplyToModel(
    messageId: map['messageId'] ?? '',
    text: map['text'] ?? '',
    senderId: map['senderId'] ?? '',
    senderName: map['senderName'] ?? '',
    sentAt: map['sentAt'] ?? ''
  );

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
    'sentAt': sentAt,
  };
}
