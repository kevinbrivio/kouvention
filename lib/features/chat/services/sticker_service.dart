import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/chat/models/sticker_model.dart';

final stickerServiceProvider = Provider<StickerService>((ref) => StickerService());

class StickerService {
  List<StickerPack> getStickerPacks() => _packs;

  StickerPack? getPackById(String id) {
    try {
      return _packs.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

final _packs = [
  StickerPack(
    id: 'smile',
    name: 'Smile',
    icon: '😊',
    stickers: [
      StickerModel(id: 'smile_1', url: 'https://media.giphy.com/media/26ufnwz3w4D5p14Fm/giphy.gif', emoji: '😊'),
      StickerModel(id: 'smile_2', url: 'https://media.giphy.com/media/l0HlNQzJynECn1x4I/giphy.gif', emoji: '😂'),
      StickerModel(id: 'smile_3', url: 'https://media.giphy.com/media/26BRv0ThDF1Nq0Hcox/giphy.gif', emoji: '😉'),
      StickerModel(id: 'smile_4', url: 'https://media.giphy.com/media/l0HlNaQ6gW0R3P1bC/giphy.gif', emoji: '😎'),
      StickerModel(id: 'smile_5', url: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', emoji: '🤪'),
      StickerModel(id: 'smile_6', url: 'https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif', emoji: '🥰'),
    ],
  ),
  StickerPack(
    id: 'celebrate',
    name: 'Celebrate',
    icon: '🎉',
    stickers: [
      StickerModel(id: 'cel_1', url: 'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif', emoji: '🎉'),
      StickerModel(id: 'cel_2', url: 'https://media.giphy.com/media/xT0xeJpnrWCiXrIkA/giphy.gif', emoji: '🎊'),
      StickerModel(id: 'cel_3', url: 'https://media.giphy.com/media/3o7abldj0b3rxrZUQw/giphy.gif', emoji: '🎆'),
      StickerModel(id: 'cel_4', url: 'https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif', emoji: '🎈'),
    ],
  ),
  StickerPack(
    id: 'animals',
    name: 'Animals',
    icon: '🐱',
    stickers: [
      StickerModel(id: 'ani_1', url: 'https://media.giphy.com/media/mlvseq9yvZhba/giphy.gif', emoji: '🐱'),
      StickerModel(id: 'ani_2', url: 'https://media.giphy.com/media/l2JegMfbLfNhx2UO0/giphy.gif', emoji: '🐶'),
      StickerModel(id: 'ani_3', url: 'https://media.giphy.com/media/l0HlGwlZCwZbnyn9e/giphy.gif', emoji: '🐰'),
      StickerModel(id: 'ani_4', url: 'https://media.giphy.com/media/26BRzizN6QGwmBMju/giphy.gif', emoji: '🐼'),
    ],
  ),
  StickerPack(
    id: 'love',
    name: 'Love',
    icon: '❤️',
    stickers: [
      StickerModel(id: 'love_1', url: 'https://media.giphy.com/media/3o7abKhOpu0Nwe6lGU/giphy.gif', emoji: '❤️'),
      StickerModel(id: 'love_2', url: 'https://media.giphy.com/media/l0HlBO8GclHOxhLG8/giphy.gif', emoji: '😘'),
      StickerModel(id: 'love_3', url: 'https://media.giphy.com/media/l4q8c9z5HrF1u6F7a/giphy.gif', emoji: '💕'),
      StickerModel(id: 'love_4', url: 'https://media.giphy.com/media/26FLdmIp6wJr91JAI/giphy.gif', emoji: '🥺'),
    ],
  ),
];
