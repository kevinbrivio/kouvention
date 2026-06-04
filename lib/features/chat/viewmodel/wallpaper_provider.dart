import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

class WallpaperConfig {
  final ImageProvider image;
  final ColorFilter? colorFilter;

  const WallpaperConfig({
    required this.image,
    this.colorFilter,
  });
}

final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, WallpaperConfig>((ref) {
  final prefs = ref.read(prefsServiceProvider);
  return WallpaperNotifier(prefs);
});

final chatWallpaperProvider = Provider.family<WallpaperConfig, String>((ref, chatId) {
  return ref.watch(wallpaperProvider);
});

class WallpaperNotifier extends StateNotifier<WallpaperConfig> {
  final PrefsService _prefs;

  WallpaperNotifier(this._prefs)
      : super(const WallpaperConfig(
          image: AssetImage('assets/images/chat_wallpaper.jpg'),
        )) {
    _loadConfig();
  }

  void _loadConfig() {
    final path = _prefs.getWallpaperPath();
    if (path != null) {
      state = WallpaperConfig(image: AssetImage(path));
    }
  }

  void setWallpaper(String? assetPath) {
    state = WallpaperConfig(
      image: assetPath != null
          ? AssetImage(assetPath)
          : const AssetImage('assets/images/chat_wallpaper.jpg'),
    );
    _prefs.setWallpaperPath(assetPath);
  }
}
