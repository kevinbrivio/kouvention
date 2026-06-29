import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:kouvention/cores/utils/log.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._() {
    _lifecycleSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
    });
    _player.positionStream.listen((pos) {
      if (_currentMessageId != null) {
        _positionController.add(pos);
      }
    });
    _player.durationStream.listen((dur) {
      if (_currentMessageId != null) {
        _durationController.add(dur);
      }
    });
  }

  static const reviewKey = '__review__';

  final AudioPlayer _player = AudioPlayer();
  String? _currentMessageId;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  late final StreamSubscription _lifecycleSub;

  String? get currentMessageId => _currentMessageId;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> play({required String messageId, required String url}) async {
    try {
      if (_currentMessageId == messageId) {
        await _player.play();
        return;
      }

      _currentMessageId = messageId;
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      _currentMessageId = null;

      try {
        await _player.stop();
      } catch (_) {}
      eLog('AudioManager.play error: $e');
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    _currentMessageId = null;
    await _player.stop();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> dispose() async {
    await _lifecycleSub.cancel();
    await _positionController.close();
    await _durationController.close();
    await _player.dispose();
  }
}
