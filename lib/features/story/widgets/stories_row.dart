import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/story/models/story_feed_item.dart';
import 'package:kouvention/features/story/models/story_model.dart';
import 'package:kouvention/features/story/services/story_upload_progress.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';

class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key, required this.onStoryTap});

  final ValueChanged<StoryFeedItem> onStoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final feed = ref.watch(storyFeedItemsProvider(uid));

    return feed.when(
      loading: () => SizedBox(height: 94.h),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 94.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => Gap(AppSpacing.sm.w),
            itemBuilder: (context, index) {
              final item = items[index];
              return _StoryAvatar(item: item, onTap: () => onStoryTap(item));
            },
          ),
        );
      },
    );
  }
}

class _StoryAvatar extends ConsumerWidget {
  const _StoryAvatar({required this.item, required this.onTap});

  final StoryFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final story = item.latestStory;
    final syncStatus = story.syncStatus;
    final isPendingOwnStory =
        item.isOwnStory &&
        (syncStatus == StorySyncStatus.pending ||
            syncStatus == StorySyncStatus.uploading);
    final isFailedOwnStory =
        item.isOwnStory && syncStatus == StorySyncStatus.failed;
    final uploadProgress = ref.watch(storyUploadProgressProvider(story.id));
    final borderColor = isFailedOwnStory
        ? scheme.error
        : item.hasUnseen || isPendingOwnStory
        ? scheme.primary
        : scheme.outline.withValues(alpha: 0.35);

    return SizedBox(
      width: 68.w,
      child: Column(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 58.r,
              height: 58.r,
              padding: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 2.r, color: borderColor),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(child: _StoryCover(item: item)),
                  if (isPendingOwnStory)
                    _StoryUploadRing(progress: uploadProgress),
                  if (isFailedOwnStory)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _StoryUploadBadge(
                        color: scheme.error,
                        icon: Icons.priority_high_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Gap(5.h),
          Text(
            item.isOwnStory ? 'My story' : item.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _StoryCover extends StatelessWidget {
  const _StoryCover({required this.item});

  final StoryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final story = item.latestStory;
    final coverUrl = item.coverUrl;
    final localPath = story.localPath?.trim();

    if (story.type == StoryType.image &&
        localPath != null &&
        localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context, story),
      );
    }

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _fallback(context, story),
      );
    }

    return _fallback(context, story);
  }

  Widget _fallback(BuildContext context, StoryModel story) {
    final scheme = Theme.of(context).colorScheme;

    return switch (story.type) {
      StoryType.audio => ColoredBox(
        color: scheme.secondaryContainer,
        child: Icon(
          Icons.graphic_eq_rounded,
          color: scheme.onSecondaryContainer,
        ),
      ),
      StoryType.text => ColoredBox(
        color: scheme.primaryContainer,
        child: Icon(
          Icons.text_fields_rounded,
          color: scheme.onPrimaryContainer,
        ),
      ),
      _ => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: scheme.onSurfaceVariant),
      ),
    };
  }
}

class _StoryUploadRing extends StatelessWidget {
  const _StoryUploadRing({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22)),
    child: Padding(
      padding: EdgeInsets.all(4.r),
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 3.r,
        backgroundColor: Colors.white.withValues(alpha: 0.28),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    ),
  );
}

class _StoryUploadBadge extends StatelessWidget {
  const _StoryUploadBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5.r),
    ),
    child: SizedBox.square(
      dimension: 18.r,
      child: Icon(icon, size: 12.r, color: Colors.white),
    ),
  );
}
