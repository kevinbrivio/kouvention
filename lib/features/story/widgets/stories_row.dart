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

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.item, required this.onTap});

  final StoryFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                border: Border.all(
                  width: 2.r,
                  color: item.hasUnseen
                      ? scheme.primary
                      : scheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: ClipOval(child: _StoryCover(item: item)),
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
