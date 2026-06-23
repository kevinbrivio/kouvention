import 'dart:io';

import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

const storyVideoMaxDuration = Duration(seconds: 30);

final storyVideoPreparationServiceProvider =
    Provider<StoryVideoPreparationService>(
      (ref) => StoryVideoPreparationService(),
    );

class StoryVideoPreparationResult {
  const StoryVideoPreparationResult({
    required this.file,
    required this.wasTrimmed,
  });

  final File file;
  final bool wasTrimmed;
}

class StoryVideoPreparationService {
  Future<StoryVideoPreparationResult> prepare(File source) async {
    final duration = await _readDuration(source);
    if (!shouldTrimStoryVideo(duration)) {
      return StoryVideoPreparationResult(file: source, wasTrimmed: false);
    }

    final trimmer = VideoTrimmer();
    await trimmer.loadVideo(source.path);
    final outputPath = await trimmer.trimVideo(
      startTimeMs: 0,
      endTimeMs: storyVideoMaxDuration.inMilliseconds,
    );
    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Video trimming did not produce an output file.');
    }

    return StoryVideoPreparationResult(
      file: File(outputPath),
      wasTrimmed: true,
    );
  }

  Future<Duration> _readDuration(File source) async {
    final controller = VideoPlayerController.file(source);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }
}

bool shouldTrimStoryVideo(Duration duration) =>
    duration > storyVideoMaxDuration;
