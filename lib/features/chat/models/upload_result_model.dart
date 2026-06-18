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

  factory UploadResultModel.fromJson(Map<String, dynamic> json) {
    final format = json['format'] as String?;
    final originalFilename = json['original_filename'] as String? ?? '';
    final url = json['secure_url'] as String? ?? '';

    // Cloudinary's original_filename doesn't include extension,
    // reconstruct full filename from original_filename + format
    final fileName = originalFilename.isNotEmpty && format != null
        ? '$originalFilename.$format'
        : originalFilename;

    // Determine type from file extension, not Cloudinary's resource_type.
    // resource_type:'auto' can misclassify files (e.g. .txt as "image").
    final messageType = _typeFromExtension(fileName, url, format);

    return UploadResultModel(
      url: url,
      fileName: fileName,
      mimeType: _buildMimeType(messageType, format),
      messageType: messageType,
      fileSizeBytes: json['bytes'],
      mediaDuration: json['duration'] != null
          ? (json['duration'] as double).round()
          : null,
      caption: json['text'],
      localPath: json['local_path'],
    );
  }

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

  /// Determine [MessageType] from file extension.
  /// Checks [fileName] first, then Cloudinary [format] (reliable extension).
  /// Falls back to [MessageType.file] for unknown extensions.
  static MessageType _typeFromExtension(
    String fileName,
    String url,
    String? format,
  ) {
    // Prefer original file name extension
    String? ext;
    if (fileName.isNotEmpty) {
      ext = fileName.split('.').last.toLowerCase();
    }

    // Fallback: extract from URL path (strip query params)
    if (ext == null && url.isNotEmpty) {
      final urlPath = url.split('?').first;
      ext = urlPath.split('.').last.toLowerCase();
    }

    // Final fallback: Cloudinary format field
    ext ??= format?.toLowerCase();
    if (ext == null) return MessageType.file;

    // Image extensions
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'gif' ||
        ext == 'webp' || ext == 'bmp' || ext == 'svg' || ext == 'heic') {
      return MessageType.image;
    }

    // Video extensions
    if (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' ||
        ext == 'webm' || ext == 'flv' || ext == 'wmv') {
      return MessageType.video;
    }

    // Audio extensions
    if (ext == 'mp3' || ext == 'wav' || ext == 'ogg' || ext == 'm4a' ||
        ext == 'aac' || ext == 'flac' || ext == 'wma' ||
        ext == 'opus' || ext == 'caf') {
      return MessageType.audio;
    }

    // Everything else is a file (pdf, docx, txt, zip, rar, etc.)
    return MessageType.file;
  }

  static String _buildMimeType(MessageType type, String? format) {
    if (format == null) return 'application/octet-stream';

    switch (type) {
      case MessageType.image:
        return 'image/${format == 'jpg' ? 'jpeg' : format}';
      case MessageType.video:
        return 'video/$format';
      case MessageType.audio:
        return 'audio/$format';
      case MessageType.file:
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
