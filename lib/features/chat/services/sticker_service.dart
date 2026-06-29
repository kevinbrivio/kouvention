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
      StickerModel(id: 'smile_1', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExbzBpaHY3ZmdscHhqa2M1ZGlld2VzZnVrb21jeXZ0Y3p5eHU2dDE4OSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Fu3OjBQiCs3s0ZuLY3/giphy.gif', emoji: '😊'),
      StickerModel(id: 'smile_2', url: 'https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExejRlMHg5YzlxNW1wMDljNWhkdXc5bG5wZXpxeHd5ZHZ6dHJ5NzJ2MiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Dy6KtvPNfNVAIEx7O6/giphy.gif', emoji: '😂'),
      StickerModel(id: 'smile_3', url: 'https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExZHBjYWlzZTF0cHk5bjJ1b3lqdTdtMzZqazBncWxzMWYzYnh6cWN4MiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/kCrGOt5ojlVbG/giphy.gif', emoji: '😉'),
      StickerModel(id: 'smile_4', url: 'https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExMHNxZDdvamp0NzlhbWd1cHZwcml5ZTNxMWhyaXZkZHg3b3ZlZXd6cyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/eruVMzXlb70oo/giphy.gif', emoji: '😎'),
      StickerModel(id: 'smile_5', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExb2w2Znl3dzZham4wbHMxajNvOXRidHFpamtnMnludDBvNXdodDBzciZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/10qcQYd6rcfS12/giphy.gif', emoji: '🤪'),
    ],
  ),
  StickerPack(
    id: 'celebrate',
    name: 'Celebrate',
    icon: '🎉',
    stickers: [
      StickerModel(id: 'cel_1', url: 'https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExY25jeXhpam8zY2ZjcGRzaWx5ZXhseTczdHI2YTJ0NndwdnphdW1lcCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/W6Lwg2xvTr6tJpuSTd/giphy.gif', emoji: '🎉'),
      StickerModel(id: 'cel_2', url: 'https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExNjNmM2V2cDZ2cm94eW1oeTF6MG9paTVpd3I2ZHlmdnR1OTJtYjAyaiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/6JzM6pW8Sa8loWxBmt/giphy.gif', emoji: '🎊'),
      StickerModel(id: 'cel_3', url: 'https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExNmhrNTZnbXlpOW96dmpzOHJvN2xoaW12YTloZTBmdnl3emtnaHg0cyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Na33dsU2umStO/giphy.gif', emoji: '🎆'),
      StickerModel(id: 'cel_4', url: 'https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExYTNtZmMyeW1hdnRiYXh2OHJtZGhzbnhiYzdqOWxwd3UzNjA5OGFxNyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/MTclfCr4tVgis/giphy.gif', emoji: '🎈'),
    ],
  ),
  StickerPack(
    id: 'animals',
    name: 'Animals',
    icon: '🐱',
    stickers: [
      StickerModel(id: 'ani_1', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExdzNtZHNiMXF3bTRxOWwwd2JrZDV6OG5rNXo3OWpsbGh1cnNpZ2NqcSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/TZBgRRkvSXIQxhi8dU/giphy.gif', emoji: '🐱'),
      StickerModel(id: 'ani_2', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExc3NhaWl3djhlanBlaXFuOTR0bTk4ZHdrZm1uNzk0cGRxNm5qaHIzYSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/gKHGnB1ml0moQdjhEJ/giphy.gif', emoji: '🐶'),
      StickerModel(id: 'ani_3', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExY3Y1MHpjMGJhZDA3cDZ4ZnBxZjVvcGQ0cjN1bnZqZm55dHZmMTBhMyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/wsJHi6a1JwoXC/giphy.gif', emoji: '🐰'),
      StickerModel(id: 'ani_4', url: 'https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExcmxxZ253OGNiMjRiZ3pjNDh3eHlyaXpmNHc0bGNxeDJ6MHY2eTJ4aSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Njk19T0bDC7ar2pA5H/giphy.gif', emoji: '🐼'),
    ],
  ),
  StickerPack(
    id: 'love',
    name: 'Love',
    icon: '❤️',
    stickers: [
      StickerModel(id: 'love_1', url: 'https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExOHVqbmF0cDQ4bWl2dDE0ZHd2c3VvOWFqbDE2aWlpOWkwNnZmbXQ5ayZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/t8xgPfC5oNIRMrNooe/giphy.gif', emoji: '❤️'),
      StickerModel(id: 'love_2', url: 'https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExcGFwYm5mYjBjcWt1NDFmd3BlMjF6MjZkeGdianhvMngzYWszMzRidCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Zl7u48zLVFgLpRwq6f/giphy.gif', emoji: '😘'),
      StickerModel(id: 'love_3', url: 'https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExejQwcWUzbXNrdWJkYTZ6NzYxcnpya2w5Z2pnZ2pxbmI0NHR5NDdoMyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/7W1rgKAxlDe3m/giphy.gif', emoji: '💕'),
      StickerModel(id: 'love_4', url: 'https://media.giphy.com/media/26FLdmIp6wJr91JAI/giphy.gif', emoji: '🥺'),
    ],
  ),
];
