import 'package:kouvention/features/chat/models/message_type.dart';

class UploadResultModel {
  final String url;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final MessageType messageType;
  final int? mediaDuration;

  const UploadResultModel({
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.messageType,
    this.mediaDuration,
  });
}
