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

/// In-memory state for the wallpaper system. Carries both the global
/// wallpaper and per-chat overrides so that any change emits a new
/// instance and invalidates [chatWallpaperProvider] / [chatWallpaperOverrideProvider].
class WallpaperState {
  final WallpaperConfig global;
  final Map<String, WallpaperConfig> chatOverrides;

  const WallpaperState({
    required this.global,
    this.chatOverrides = const {},
  });

  /// Effective wallpaper for [chatId]: override if present, else global.
  WallpaperConfig resolveForChat(String chatId) =>
      chatOverrides[chatId] ?? global;

  /// Per-chat override, or null when the chat follows the global setting.
  WallpaperConfig? overrideFor(String chatId) => chatOverrides[chatId];

  WallpaperState copyWith({
    WallpaperConfig? global,
    Map<String, WallpaperConfig>? chatOverrides,
  }) =>
      WallpaperState(
        global: global ?? this.global,
        chatOverrides: chatOverrides ?? this.chatOverrides,
      );
}

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, WallpaperState>((ref) {
  return WallpaperNotifier(ref);
});

/// Effective wallpaper for [chatId] (override or global). Reactive —
/// rebuilds on any global or per-chat wallpaper change.
final chatWallpaperProvider = Provider.family<WallpaperConfig, String>((
  ref,
  chatId,
) {
  return ref.watch(wallpaperProvider).resolveForChat(chatId);
});

/// Per-chat override for [chatId], or null if the chat follows global.
/// Reactive — rebuilds on any per-chat wallpaper change.
final chatWallpaperOverrideProvider =
    Provider.family<WallpaperConfig?, String>((ref, chatId) {
  return ref.watch(wallpaperProvider).overrideFor(chatId);
});

class WallpaperNotifier extends StateNotifier<WallpaperState> {
  final Ref _ref;

  WallpaperNotifier(this._ref) : super(_initialState()) {
    _loadFromPrefs();
  }

  static WallpaperState _initialState() => WallpaperState(
        global: WallpaperConfig(image: AssetImage(images.chatWallpaper)),
      );

  static WallpaperConfig _defaultConfig() =>
      WallpaperConfig(image: AssetImage(images.chatWallpaper));

  PrefsService get _prefs => _ref.read(prefsServiceProvider);
  WallpaperService get _service => _ref.read(wallpaperServiceProvider);

  void _loadFromPrefs() {
    final global = _decode(_prefs.getWallpaperPath()) ?? _defaultConfig();

    final overrides = <String, WallpaperConfig>{};
    for (final chatId in _prefs.getChatWallpaperKeys()) {
      final stored = _prefs.getChatWallpaperPath(chatId);
      if (stored == null) continue;
      final decoded = _decode(stored);
      if (decoded != null) overrides[chatId] = decoded;
    }

    state = WallpaperState(global: global, chatOverrides: overrides);
  }

  // --- GLOBAL ---

  Future<void> pickAndSetFromGallery() async {
    final file = await _service.pickAndCrop();
    if (file == null) return;
    await _replaceGlobalWithFile(file);
  }

  Future<void> setDefault() async {
    await _deleteUserFileIfPresent();
    state = state.copyWith(global: _defaultConfig());
    await _prefs.setWallpaperPath(_defaultConfig().storedValue);
  }

  Future<void> setRemoved() async {
    await _deleteUserFileIfPresent();
    state = state.copyWith(global: const WallpaperConfig());
    await _prefs.setWallpaperPath(null);
  }

  // --- PER-CHAT ---

  Future<void> pickAndSetForChat(String chatId) async {
    final file = await _service.pickAndCrop();
    if (file == null) return;
    final newConfig = WallpaperConfig(image: FileImage(file));
    final previousPath = _extractFilePath(state.chatOverrides[chatId]?.storedValue);
    await _prefs.setChatWallpaperPath(chatId, newConfig.storedValue);
    state = state.copyWith(
      chatOverrides: {...state.chatOverrides, chatId: newConfig},
    );
    if (previousPath != null) await _service.deleteFile(previousPath);
  }

  Future<void> resetForChat(String chatId) async {
    final previousPath = _extractFilePath(state.chatOverrides[chatId]?.storedValue);
    if (previousPath == null && !state.chatOverrides.containsKey(chatId)) {
      return;
    }
    final next = {...state.chatOverrides}..remove(chatId);
    await _prefs.setChatWallpaperPath(chatId, null);
    state = state.copyWith(chatOverrides: next);
    if (previousPath != null) await _service.deleteFile(previousPath);
  }

  // --- HELPERS ---

  Future<void> _replaceGlobalWithFile(File file) async {
    await _deleteUserFileIfPresent();
    final newConfig = WallpaperConfig(image: FileImage(file));
    state = state.copyWith(global: newConfig);
    await _prefs.setWallpaperPath(newConfig.storedValue);
  }

  Future<void> _deleteUserFileIfPresent() async {
    final path = _extractFilePath(state.global.storedValue);
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
