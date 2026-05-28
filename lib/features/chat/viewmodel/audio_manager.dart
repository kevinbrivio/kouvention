import 'package:just_audio/just_audio.dart';

class AudioManager {
  // Hanya ada 1 AudioManager di seluruh app
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  final AudioPlayer _player = AudioPlayer();
  String? currentUrl;

  Future<void> play(String url) async {
    if (currentUrl == url) {
      await _player.play();
      return;
    }
    currentUrl = url;
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() async => await _player.pause();
  Future<void> stop() async {
    currentUrl = null;
    await _player.stop();
  }

  // Stream posisi (untuk slider)
  Stream<Duration> get positionStream => _player.positionStream;
  // Stream durasi
  Stream<Duration?> get durationStream => _player.durationStream;
  // Stream status play/pause
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}