import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  final AudioPlayer _player = AudioPlayer();
  String? currentUrl;

  Future<void> play(String url) async {
    try {
      if (currentUrl == url) {
        await _player.play();
        return;
      }
      currentUrl = url;
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint('AudioManager.play error: $e');
    }
  }

  Future<void> pause() async => await _player.pause();
  Future<void> stop() async {
    currentUrl = null;
    await _player.stop();
  }

  // Stream current position for slider
  Stream<Duration> get positionStream => _player.positionStream;
  // Stream duration used for displaying in UI
  Stream<Duration?> get durationStream => _player.durationStream;
  // Stream status of current recording state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}