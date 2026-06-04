import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/constants/image_paths.dart';
import 'package:kouvention/features/chat/services/wallpaper_service.dart';
import 'package:kouvention/features/shared/services/prefs_service.dart';

const _assetPrefix = 'asset:';
const _filePrefix = 'file:';

final wallpaperServiceProvider = Provider<WallpaperService>((ref) {
  return WallpaperService();
});

/// Represents the current wallpaper. `image == null` means "no wallpaper
/// (chat room shows plain background)". A non-null image is shown behind
/// the chat and adapted for dark mode by BaseView.
class WallpaperConfig {
  final ImageProvider? image;
  final ColorFilter? colorFilter;

  const WallpaperConfig({this.image, this.colorFilter});

  /// Serialized form for PrefsService:
  ///   `null`            → removed / no wallpaper
  ///   `'asset:path'`    → bundled asset
  ///   `'file:path'`     → user-picked local file
  String? get storedValue {
    final img = image;
    if (img == null) return null;
    if (img is AssetImage) return '$_assetPrefix${img.assetName}';
    if (img is FileImage) return '$_filePrefix${img.file.path}';
    return null;
  }

  bool get isRemoved => image == null;
  bool get isFile => image is FileImage;
  bool get isDefaultAsset => image is AssetImage;
}

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, WallpaperConfig>((ref) {
      return WallpaperNotifier(ref);
    });

final chatWallpaperProvider = Provider.family<WallpaperConfig, String>((
  ref,
  chatId,
) {
  final notifier = ref.read(wallpaperProvider.notifier);
  return notifier.resolveForChat(chatId);
});

/// Whether [chatId] has its own wallpaper override set in prefs.
/// (Returns the raw stored value: null means "follow global".)
final chatWallpaperOverrideProvider =
    Provider.family<String?, String>((ref, chatId) {
  ref.watch(wallpaperProvider);
  return ref.read(prefsServiceProvider).getChatWallpaperPath(chatId);
});

class WallpaperNotifier extends StateNotifier<WallpaperConfig> {
  final Ref _ref;

  WallpaperNotifier(this._ref) : super(_defaultConfig()) {
    _loadGlobal();
  }

  static WallpaperConfig _defaultConfig() =>
      WallpaperConfig(image: AssetImage(images.chatWallpaper));

  PrefsService get _prefs => _ref.read(prefsServiceProvider);
  WallpaperService get _service => _ref.read(wallpaperServiceProvider);

  void _loadGlobal() {
    final stored = _prefs.getWallpaperPath();
    final decoded = _decode(stored);
    state = decoded ?? _defaultConfig();
  }

  /// Returns the effective wallpaper for [chatId] (override or global).
  WallpaperConfig resolveForChat(String chatId) {
    final override = _prefs.getChatWallpaperPath(chatId);
    if (override == null) return state;
    return _decode(override) ?? state;
  }

  Future<void> pickAndSetFromGallery() async {
    final file = await _service.pickAndCrop();
    if (file == null) return;
    await _replaceWithFile(file);
  }

  Future<void> pickAndSetForChat(String chatId) async {
    final file = await _service.pickAndCrop();
    if (file == null) return;
    final previousPath = _extractFilePath(_prefs.getChatWallpaperPath(chatId));
    await _prefs.setChatWallpaperPath(chatId, '$_filePrefix${file.path}');
    if (previousPath != null) {
      await _service.deleteFile(previousPath);
    }
  }

  Future<void> setDefault() async {
    await _deleteUserFileIfPresent();
    state = _defaultConfig();
    await _prefs.setWallpaperPath(_defaultConfig().storedValue);
  }

  Future<void> setRemoved() async {
    await _deleteUserFileIfPresent();
    state = const WallpaperConfig();
    await _prefs.setWallpaperPath(null);
  }

  Future<void> resetForChat(String chatId) async {
    final previousPath = _extractFilePath(_prefs.getChatWallpaperPath(chatId));
    await _prefs.setChatWallpaperPath(chatId, null);
    if (previousPath != null) {
      await _service.deleteFile(previousPath);
    }
  }

  Future<void> _replaceWithFile(File file) async {
    await _deleteUserFileIfPresent();
    state = WallpaperConfig(image: FileImage(file));
    await _prefs.setWallpaperPath(state.storedValue);
  }

  Future<void> _deleteUserFileIfPresent() async {
    final path = _extractFilePath(state.storedValue);
    if (path != null) await _service.deleteFile(path);
  }

  WallpaperConfig? _decode(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (stored.startsWith(_assetPrefix)) {
      final asset = stored.substring(_assetPrefix.length);
      return WallpaperConfig(image: AssetImage(asset));
    }
    if (stored.startsWith(_filePrefix)) {
      final path = stored.substring(_filePrefix.length);
      if (File(path).existsSync()) {
        return WallpaperConfig(image: FileImage(File(path)));
      }
    }
    return null;
  }

  String? _extractFilePath(String? stored) {
    if (stored == null || !stored.startsWith(_filePrefix)) return null;
    return stored.substring(_filePrefix.length);
  }
}
