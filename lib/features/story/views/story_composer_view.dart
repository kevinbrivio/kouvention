import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/services/media/cloud_media_service.dart';
import 'package:oktoast/oktoast.dart';
import 'package:uuid/uuid.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/story/models/story_composer_args.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_audio_composer.dart';
import 'package:kouvention/features/story/widgets/story_photo_composer.dart';
import 'package:kouvention/features/story/widgets/story_video_composer.dart';

const storyBackgroundColors = [
  Color(0xFF168C4B),
  Color(0xFF2864B7),
  Color(0xFF7047A3),
  Color(0xFFD66A1F),
  Color(0xFFB83B45),
  Color(0xFF30343B),
];

class StoryComposerView extends ConsumerStatefulWidget {
  const StoryComposerView({super.key, required this.args});

  final StoryComposerArgs args;

  @override
  ConsumerState<StoryComposerView> createState() => _StoryComposerViewState();
}

class _StoryComposerViewState extends ConsumerState<StoryComposerView> {
  final _textController = TextEditingController();
  final _photoCaptionController = TextEditingController();
  final _videoCaptionController = TextEditingController();
  final _audioCaptionController = TextEditingController();
  final _textFocusNode = FocusNode();
  late final CarouselSliderController _carouselController;
  late int _currentIndex;
  Color _backgroundColor = storyBackgroundColors.first;
  Color _audioBackgroundColor = storyBackgroundColors.last;
  File? _photoFile;
  File? _videoFile;
  File? _audioFile;
  bool _isPublishing = false;

  StoryCreationMode get _currentMode => StoryCreationMode.values[_currentIndex];

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();
    _currentIndex = widget.args.initialMode.index;
    _textController.addListener(_onTextChanged);
    if (_currentMode == StoryCreationMode.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _textFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _photoCaptionController.dispose();
    _videoCaptionController.dispose();
    _audioCaptionController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _publishTextStory() async {
    final text = _textController.text.trim();
    if (!isValidTextStory(text) || _isPublishing) return;

    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) {
      showToast('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isPublishing = true);

    final db = ref.read(messageDatabaseProvider);
    late final Set<String> visibleTo;
    try {
      visibleTo = await db.getCachedDirectContactUids(currentUser.uid);
    } catch (_) {
      showToast('Could not prepare the story audience.');
      if (mounted) setState(() => _isPublishing = false);
      return;
    }

    final profile = ref
        .read(storyCurrentUserProfileProvider(currentUser.uid))
        .valueOrNull;
    final createdAt = DateTime.now();
    final story = StoryModel(
      id: const Uuid().v4(),
      authorUid: currentUser.uid,
      authorName: profile?.displayName ?? currentUser.displayName ?? 'Unknown',
      authorPhotoUrl: profile?.photoUrl ?? currentUser.photoURL,
      type: StoryType.text,
      text: text,
      backgroundColorArgb: _backgroundColor.toARGB32(),
      visibleTo: visibleTo.toList(growable: false),
      createdAt: createdAt,
      expiresAt: storyExpiryFrom(createdAt),
      syncStatus: StorySyncStatus.pending,
    );

    try {
      await ref.read(storyRepositoryProvider).publishStory(story);
      if (mounted) context.pop();
    } catch (_) {
      final localStory = await db.getStoryById(story.id);
      if (localStory != null) {
        showToast('Story saved and queued for retry.');
        if (mounted) context.pop();
      } else {
        showToast('Could not save the story. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _publishPhotoStory() async {
    final photo = _photoFile;
    if (photo == null || _isPublishing) return;

    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) {
      showToast('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final upload = await ref
          .read(cloudMediaServiceProvider)
          .uploadFile(file: photo, mediaType: MessageType.image);
      if (upload == null || upload.url.isEmpty) {
        showToast('Could not upload the photo. Please try again.');
        return;
      }

      final db = ref.read(messageDatabaseProvider);
      final visibleTo = await db.getCachedDirectContactUids(currentUser.uid);
      final profile = ref
          .read(storyCurrentUserProfileProvider(currentUser.uid))
          .valueOrNull;
      final createdAt = DateTime.now();
      final caption = _photoCaptionController.text.trim();
      final story = StoryModel(
        id: const Uuid().v4(),
        authorUid: currentUser.uid,
        authorName:
            profile?.displayName ?? currentUser.displayName ?? 'Unknown',
        authorPhotoUrl: profile?.photoUrl ?? currentUser.photoURL,
        type: StoryType.image,
        mediaUrl: upload.url,
        caption: caption.isEmpty ? null : caption,
        localPath: photo.path,
        visibleTo: visibleTo.toList(growable: false),
        createdAt: createdAt,
        expiresAt: storyExpiryFrom(createdAt),
        syncStatus: StorySyncStatus.pending,
      );

      try {
        await ref.read(storyRepositoryProvider).publishStory(story);
        if (mounted) context.pop();
      } catch (_) {
        final localStory = await db.getStoryById(story.id);
        if (localStory != null) {
          showToast('Story saved and queued for retry.');
          if (mounted) context.pop();
        } else {
          showToast('Could not save the story. Please try again.');
        }
      }
    } catch (_) {
      showToast('Could not publish the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _publishVideoStory() async {
    final video = _videoFile;
    if (video == null || _isPublishing) return;

    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) {
      showToast('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final upload = await ref
          .read(cloudMediaServiceProvider)
          .uploadFile(file: video, mediaType: MessageType.video);
      if (upload == null || upload.url.isEmpty) {
        showToast('Could not upload the video. Please try again.');
        return;
      }

      final db = ref.read(messageDatabaseProvider);
      final visibleTo = await db.getCachedDirectContactUids(currentUser.uid);
      final profile = ref
          .read(storyCurrentUserProfileProvider(currentUser.uid))
          .valueOrNull;
      final createdAt = DateTime.now();
      final caption = _videoCaptionController.text.trim();
      final story = StoryModel(
        id: const Uuid().v4(),
        authorUid: currentUser.uid,
        authorName:
            profile?.displayName ?? currentUser.displayName ?? 'Unknown',
        authorPhotoUrl: profile?.photoUrl ?? currentUser.photoURL,
        type: StoryType.video,
        mediaUrl: upload.url,
        caption: caption.isEmpty ? null : caption,
        localPath: video.path,
        visibleTo: visibleTo.toList(growable: false),
        createdAt: createdAt,
        expiresAt: storyExpiryFrom(createdAt),
        syncStatus: StorySyncStatus.pending,
      );

      try {
        await ref.read(storyRepositoryProvider).publishStory(story);
        if (mounted) context.pop();
      } catch (_) {
        final localStory = await db.getStoryById(story.id);
        if (localStory != null) {
          showToast('Story saved and queued for retry.');
          if (mounted) context.pop();
        } else {
          showToast('Could not save the story. Please try again.');
        }
      }
    } catch (_) {
      showToast('Could not publish the video. Please try again.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _publishAudioStory() async {
    final audio = _audioFile;
    if (audio == null || _isPublishing) return;

    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) {
      showToast('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final upload = await ref
          .read(cloudMediaServiceProvider)
          .uploadFile(file: audio, mediaType: MessageType.audio);
      if (upload == null || upload.url.isEmpty) {
        showToast('Could not upload the recording. Please try again.');
        return;
      }

      final db = ref.read(messageDatabaseProvider);
      final visibleTo = await db.getCachedDirectContactUids(currentUser.uid);
      final profile = ref
          .read(storyCurrentUserProfileProvider(currentUser.uid))
          .valueOrNull;
      final createdAt = DateTime.now();
      final caption = _audioCaptionController.text.trim();
      final story = StoryModel(
        id: const Uuid().v4(),
        authorUid: currentUser.uid,
        authorName:
            profile?.displayName ?? currentUser.displayName ?? 'Unknown',
        authorPhotoUrl: profile?.photoUrl ?? currentUser.photoURL,
        type: StoryType.audio,
        mediaUrl: upload.url,
        caption: caption.isEmpty ? null : caption,
        localPath: audio.path,
        backgroundColorArgb: _audioBackgroundColor.toARGB32(),
        visibleTo: visibleTo.toList(growable: false),
        createdAt: createdAt,
        expiresAt: storyExpiryFrom(createdAt),
        syncStatus: StorySyncStatus.pending,
      );

      try {
        await ref.read(storyRepositoryProvider).publishStory(story);
        if (mounted) context.pop();
      } catch (_) {
        final localStory = await db.getStoryById(story.id);
        if (localStory != null) {
          showToast('Story saved and queued for retry.');
          if (mounted) context.pop();
        } else {
          showToast('Could not save the story. Please try again.');
        }
      }
    } catch (_) {
      showToast('Could not publish the recording. Please try again.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPublish =
        _currentMode == StoryCreationMode.text &&
        isValidTextStory(_textController.text) &&
        !_isPublishing;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CarouselSlider(
            carouselController: _carouselController,
            items: [
              StoryVideoComposer(
                isActive: _currentMode == StoryCreationMode.video,
                video: _videoFile,
                captionController: _videoCaptionController,
                isPublishing: _isPublishing,
                onVideoSelected: (video) {
                  setState(() => _videoFile = video);
                },
                onPublish: _publishVideoStory,
              ),
              StoryPhotoComposer(
                isActive: _currentMode == StoryCreationMode.photo,
                photo: _photoFile,
                captionController: _photoCaptionController,
                isPublishing: _isPublishing,
                onPhotoSelected: (photo) {
                  setState(() => _photoFile = photo);
                },
                onPublish: _publishPhotoStory,
              ),
              _TextStoryComposer(
                controller: _textController,
                focusNode: _textFocusNode,
                backgroundColor: _backgroundColor,
              ),
              StoryAudioComposer(
                isActive: _currentMode == StoryCreationMode.voice,
                audio: _audioFile,
                captionController: _audioCaptionController,
                backgroundColor: _audioBackgroundColor,
                backgroundColors: storyBackgroundColors,
                isPublishing: _isPublishing,
                onAudioSelected: (audio) {
                  setState(() => _audioFile = audio);
                },
                onBackgroundColorSelected: (color) {
                  setState(() => _audioBackgroundColor = color);
                },
                onPublish: _publishAudioStory,
              ),
            ],
            options: CarouselOptions(
              initialPage: widget.args.initialMode.index,
              height: double.infinity,
              viewportFraction: 1,
              enableInfiniteScroll: false,
              onPageChanged: (index, _) {
                setState(() => _currentIndex = index);
                if (_currentMode == StoryCreationMode.text) {
                  _textFocusNode.requestFocus();
                } else {
                  _textFocusNode.unfocus();
                }
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isPublishing ? null : context.pop,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      _currentMode.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          if (_currentMode == StoryCreationMode.text)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              child: Row(
                children: [
                  Expanded(
                    child: _ColorPalette(
                      selectedColor: _backgroundColor,
                      onSelected: (color) {
                        setState(() => _backgroundColor = color);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    tooltip: 'Publish story',
                    onPressed: canPublish ? _publishTextStory : null,
                    backgroundColor: canPublish ? Colors.white : Colors.white38,
                    foregroundColor: _backgroundColor,
                    child: _isPublishing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on StoryCreationMode {
  String get label => switch (this) {
    StoryCreationMode.video => 'Video',
    StoryCreationMode.photo => 'Photo',
    StoryCreationMode.text => 'Text',
    StoryCreationMode.voice => 'Voice',
  };
}

class _TextStoryComposer extends StatelessWidget {
  const _TextStoryComposer({
    required this.controller,
    required this.focusNode,
    required this.backgroundColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH.w,
          vertical: AppSpacing.betweenCards.h,
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          maxLength: 100,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.multiline,
          style: context.text.headlineSmall,
          decoration: const InputDecoration(
            hintText: 'Type a story',
            hintStyle: TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
          ),
        ),
      ),
    ),
  );
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.selectedColor, required this.onSelected});

  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final color in storyBackgroundColors)
          Padding(
            padding: const EdgeInsets.only(right: 10),
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
