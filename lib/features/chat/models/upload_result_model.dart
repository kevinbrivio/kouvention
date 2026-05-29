import 'package:kouvention/features/chat/models/message_type.dart';

class UploadResultModel {
  final String url;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final MessageType messageType;
  final int? mediaDuration;
  final String? caption;
  final String? localPath;

  const UploadResultModel({
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.messageType,
    this.mediaDuration,
    this.caption,
    this.localPath,
  });

  factory UploadResultModel.fromJson(Map<String, dynamic> json) =>
      UploadResultModel(
        url: json['secure_url'],
        fileName: json['original_filename'],
        mimeType: _buildMimeType(json['resource_type'], json['format']),
        fileSizeBytes: json['bytes'],
        mediaDuration: json['duration'] != null
            ? (json['duration'] as double).round()
            : null,
        messageType: MessageType.fromString(json['resource_type']),
        caption: json['text'],
        localPath: json['local_path'],
      );

  UploadResultModel copyWith({
    String? url,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    MessageType? messageType,
    int? mediaDuration,
    String? caption,
    String? localPath,
  }) => UploadResultModel(
    url: url ?? this.url,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    messageType: messageType ?? this.messageType,
    mediaDuration: mediaDuration ?? this.mediaDuration,
    caption: caption ?? this.caption,
    localPath: localPath ?? this.localPath,
  );

  static String _buildMimeType(String? resourceType, String? format) {
    if (resourceType == null || format == null)
      return 'application/octet-stream';

    switch (resourceType) {
      case 'image':
        return 'image/${format == 'jpg' ? 'jpeg' : format}';
      case 'video':
        return 'video/$format';
      case 'raw':
        return _rawMimeType(format);
      default:
        return 'application/octet-stream';
    }
  }

  static String _rawMimeType(String format) {
    switch (format) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
