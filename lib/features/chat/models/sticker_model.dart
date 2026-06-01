class StickerModel {
  final String id;
  final String url;
  final String? emoji;

  const StickerModel({
    required this.id,
    required this.url,
    this.emoji,
  });
}

class StickerPack {
  final String id;
  final String name;
  final String icon;
  final List<StickerModel> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.icon,
    required this.stickers,
  });
}
