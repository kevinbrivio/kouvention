class ReplyToModel {
  final String messageId;
  final String text;
  final String senderId;
  final String senderName;

  ReplyToModel({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.senderName,
  });

  factory ReplyToModel.fromMap(Map<String, dynamic> map) => ReplyToModel(
    messageId: map['messageId'] ?? '',
    text: map['text'] ?? '',
    senderId: map['senderId'] ?? '',
    senderName: map['senderName'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'text': text,
    'senderId': senderId,
    'senderName': senderName,
  };
}
