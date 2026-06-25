import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:oktoast/oktoast.dart';
import 'package:record/record.dart';

const storyAudioMaxDuration = Duration(seconds: 30);

class StoryAudioComposer extends StatefulWidget {
  const StoryAudioComposer({
    super.key,
    required this.isActive,
    required this.audio,
    required this.backgroundColor,
    required this.backgroundColors,
    required this.isPublishing,
    required this.onAudioSelected,
    required this.onBackgroundColorSelected,
    required this.onPublish,
  });

  final bool isActive;
  final File? audio;
  final Color backgroundColor;
  final List<Color> backgroundColors;
  final bool isPublishing;
  final ValueChanged<File?> onAudioSelected;
  final ValueChanged<Color> onBackgroundColorSelected;
  final ValueChanged<int> onPublish;

  @override
  State<StoryAudioComposer> createState() => _StoryAudioComposerState();
}

class _StoryAudioComposerState extends State<StoryAudioComposer>
    with WidgetsBindingObserver {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final List<double> _amplitudeSamples = [];
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.audio != null) {
      unawaited(_preparePlayer(widget.audio!));
    }
  }

  @override
  void didUpdateWidget(covariant StoryAudioComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isActive && oldWidget.isActive) {
      unawaited(_cancelRecording());
      unawaited(_player.stop());
    }

    if (widget.audio?.path != oldWidget.audio?.path) {
      if (widget.audio == null) {
        unawaited(_player.stop());
      } else {
        unawaited(_preparePlayer(widget.audio!));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_cancelRecording());
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isPreparing || _isRecording || widget.audio != null) return;

    setState(() => _isPreparing = true);
    try {
      if (!await _recorder.hasPermission()) {
        showToast('Microphone permission is required to record a story.');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp('kou_story_audio_');
      final supportsOpus = await _recorder.isEncoderSupported(
        AudioEncoder.opus,
      );
      final encoder = supportsOpus ? AudioEncoder.opus : AudioEncoder.aacLc;
      final extension = supportsOpus ? 'opus' : 'm4a';
      final path =
          '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 32000,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      _amplitudeSamples.clear();
      _recordingDuration = Duration.zero;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;

        final next = _recordingDuration + const Duration(seconds: 1);
        if (next >= storyAudioMaxDuration) {
          setState(() => _recordingDuration = storyAudioMaxDuration);
          unawaited(_stopRecording());
        } else {
          setState(() => _recordingDuration = next);
        }
      });
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amplitude) {
            final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
            if (!mounted) return;
            setState(() {
              _amplitudeSamples.add(normalized);
              if (_amplitudeSamples.length > 80) {
                _amplitudeSamples.removeAt(0);
              }
            });
          });

      if (mounted) setState(() => _isRecording = true);
    } catch (_) {
      showToast('Could not start recording. Please try again.');
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      final path = await _recorder.stop();
      if (path == null) {
        showToast('Could not save the recording. Please try again.');
        return;
      }

      final audio = File(path);
      widget.onAudioSelected(audio);
      await _preparePlayer(audio);
    } catch (_) {
      showToast('Could not save the recording. Please try again.');
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _recorder.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
        _amplitudeSamples.clear();
      });
    }
  }

  Future<void> _preparePlayer(File audio) async {
    try {
      await _player.setFilePath(audio.path);
    } catch (_) {
      showToast('Could not load the recording preview.');
    }
  }

  Future<void> _togglePlayback() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> _retake() async {
    await _player.stop();
    widget.onAudioSelected(null);
    setState(() {
      _recordingDuration = Duration.zero;
      _amplitudeSamples.clear();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.backgroundColor,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 20),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StoryAudioWaveform(
                    samples: _amplitudeSamples,
                    isActive: _isRecording || _player.playing,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? 'Recording...'
                        : widget.audio == null
                        ? 'Tap to record'
                        : 'Recording ready',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildActions(),
            const SizedBox(height: 16),
            _AudioColorPalette(
              colors: widget.backgroundColors,
              selectedColor: widget.backgroundColor,
              onSelected: widget.onBackgroundColorSelected,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildActions() {
    if (widget.audio == null) {
      return GestureDetector(
        onTap: _isPreparing
            ? null
            : _isRecording
            ? _stopRecording
            : _startRecording,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isRecording ? 32 : 62,
              height: _isRecording ? 32 : 62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: _isRecording ? BorderRadius.circular(6) : null,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AudioAction(
          tooltip: 'Retake',
          icon: Icons.refresh_rounded,
          onPressed: widget.isPublishing ? null : _retake,
        ),
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) => _AudioAction(
            tooltip: _player.playing ? 'Pause' : 'Play',
            icon: _player.playing ? Icons.pause_rounded : Icons.play_arrow,
            onPressed: widget.isPublishing ? null : _togglePlayback,
          ),
        ),
        _AudioAction(
          tooltip: 'Publish story',
          icon: Icons.send_rounded,
          isLoading: widget.isPublishing,
          onPressed: widget.isPublishing
              ? null
              : () => widget.onPublish(_recordingDuration.inSeconds),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class StoryAudioWaveform extends StatelessWidget {
  const StoryAudioWaveform({
    super.key,
    required this.samples,
    required this.isActive,
  });

  final List<double> samples;
  final bool isActive;

  static const _placeholder = <double>[
    0.16,
    0.32,
    0.56,
    0.28,
    0.72,
    0.42,
    0.88,
    0.34,
    0.64,
    0.24,
    0.48,
    0.76,
    0.38,
    0.58,
    0.2,
    0.44,
    0.68,
    0.3,
    0.52,
    0.18,
  ];

  @override
  Widget build(BuildContext context) {
    final values = samples.isEmpty ? _placeholder : samples;

    return SizedBox(
      height: 112,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visibleCount = (constraints.maxWidth / 8).floor().clamp(
            1,
            values.length,
          );
          final visible = values.sublist(values.length - visibleCount);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final value in visible)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 4,
                  height: 16 + (value * 80),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isActive ? 1 : 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AudioColorPalette extends StatelessWidget {
  const _AudioColorPalette({
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelected(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == color
                        ? Colors.white
                        : Colors.white54,
                    width: selectedColor == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AudioAction extends StatelessWidget {
  const _AudioAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black38,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.black26,
      disabledForegroundColor: Colors.white38,
      minimumSize: const Size.square(52),
    ),
    icon: isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : Icon(icon),
  );
}
