import 'dart:async';
import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/story/repositories/story_repository.dart';
import 'package:oktoast/oktoast.dart';
import 'package:uuid/uuid.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/story/models/story_composer_args.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/services/story_sync_coordinator.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_audio_composer.dart';
import 'package:kouvention/features/story/widgets/story_photo_composer.dart';
import 'package:kouvention/features/story/widgets/story_video_composer.dart';

const storyBackgroundColors = [
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
    await _queueMediaStory(
      file: photo,
      type: StoryType.image,
      captionController: _photoCaptionController,
      failureMessage: 'Could not save the photo story. Please try again.',
    );
  }

  Future<void> _publishVideoStory(int mediaDuration) async {
    final video = _videoFile;
    if (video == null || _isPublishing) return;
    await _queueMediaStory(
      file: video,
      type: StoryType.video,
      captionController: _videoCaptionController,
      failureMessage: 'Could not save the video story. Please try again.',
      mediaDuration: mediaDuration,
    );
  }

  Future<void> _publishAudioStory(int mediaDuration) async {
    final audio = _audioFile;
    if (audio == null || _isPublishing) return;

    await _queueMediaStory(
      file: audio,
      type: StoryType.audio,
      backgroundColorArgb: _audioBackgroundColor.toARGB32(),
      failureMessage: 'Could not save the recording story. Please try again.',
      mediaDuration: mediaDuration,
    );
  }

  Future<void> _queueMediaStory({
    required File file,
    required StoryType type,
    required String failureMessage,
    TextEditingController? captionController,
    int? backgroundColorArgb,
    int? mediaDuration,
  }) async {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) {
      showToast('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isPublishing = true);

    final db = ref.read(messageDatabaseProvider);
    try {
      final visibleTo = await db.getCachedDirectContactUids(currentUser.uid);
      final profile = ref
          .read(storyCurrentUserProfileProvider(currentUser.uid))
          .valueOrNull;
      final createdAt = DateTime.now();
      final caption = captionController?.text.trim();
      final story = StoryModel(
        id: const Uuid().v4(),
        authorUid: currentUser.uid,
        authorName:
            profile?.displayName ?? currentUser.displayName ?? 'Unknown',
        authorPhotoUrl: profile?.photoUrl ?? currentUser.photoURL,
        type: type,
        caption: caption?.isEmpty == false ? caption : null,
        localPath: file.path,
        backgroundColorArgb: backgroundColorArgb,
        visibleTo: visibleTo.toList(growable: false),
        createdAt: createdAt,
        expiresAt: storyExpiryFrom(createdAt),
        mediaDuration: mediaDuration,
        syncStatus: StorySyncStatus.pending,
      );

      await ref.read(storyRepositoryProvider).queueStory(story);
      unawaited(ref.read(storySyncCoordinatorProvider).flushPending());
      if (mounted) context.pop();
    } catch (_) {
      showToast(failureMessage);
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: AppSizing.iconMd.r,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_currentMode == StoryCreationMode.text)
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    8.h,
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
                      heroTag: null,
                      tooltip: 'Publish status',
                      onPressed: canPublish ? _publishTextStory : null,
                      backgroundColor: canPublish
                          ? Colors.white
                          : Colors.white38,
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
      ),
    );
  }
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
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screenH.w,
            right: AppSpacing.screenH.w,
            top: AppSpacing.betweenCards.h,
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
                width: AppSizing.iconLg.w,
                height: AppSizing.iconLg.w,
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
