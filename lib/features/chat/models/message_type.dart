enum MessageType {
  text,
  image,
  video,
  audio,
  file, // pdf, docx, xlxs, etc.
  media;

  static MessageType fromString(String value) => MessageType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MessageType.text, // fallback
  );
}