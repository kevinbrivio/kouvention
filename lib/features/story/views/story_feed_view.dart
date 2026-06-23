import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/story/models/story_composer_args.dart';
import 'package:kouvention/features/story/models/story_feed_item.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/viewmodel/story_feed_viewmodel.dart';
import 'package:kouvention/features/story/widgets/story_author_avatar.dart';

class StoryFeedView extends ConsumerStatefulWidget {
  const StoryFeedView({super.key});

  @override
  ConsumerState<StoryFeedView> createState() => _StoryFeedViewState();
}

class _StoryFeedViewState extends ConsumerState<StoryFeedView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final scheme = Theme.of(context).colorScheme;

    if (currentUser == null) {
      return BaseView(
        provider: storyFeedVM,
        useGradient: false,
        backgroundColor: scheme.surface,
        builder: (_, _) => const SizedBox.shrink(),
      );
    }

    final feed = ref.watch(storyFeedItemsProvider(currentUser.uid));
    final viewedStoryIds =
        ref.watch(viewedStoryIdsProvider(currentUser.uid)).valueOrNull ??
        const <String>{};
    final currentProfile = ref
        .watch(storyCurrentUserProfileProvider(currentUser.uid))
        .valueOrNull;

    return BaseView(
      provider: storyFeedVM,
      useGradient: false,
      builder: (context, _) => Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                    vertical: AppSpacing.sm.h,
                  ),
                  child: Text(
                    'Updates',
                    style: context.text.titleLarge.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md.w,
                    0,
                    AppSpacing.md.w,
                    AppSpacing.sm.h,
                  ),
                  child: _StorySearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onClear: _searchQuery.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                  ),
                ),
                Expanded(
                  child: feed.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const _StoryFeedMessage(
                      icon: Icons.cloud_off_outlined,
                      message: 'Stories are unavailable',
                    ),
                    data: (items) {
                      final ownStory = _ownStory(items);
                      final visibleItems = searchStoryFeedItemsByAuthor(
                        items,
                        _searchQuery,
                      );
                      final isSearching = _searchQuery.trim().isNotEmpty;
                      final unseenUpdates = visibleItems
                          .where((item) => !item.isOwnStory && item.hasUnseen)
                          .toList();
                      final viewedUpdates = visibleItems
                          .where((item) => !item.isOwnStory && !item.hasUnseen)
                          .toList();

                      return ListView(
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).padding.bottom +
                              AppSpacing.xl.h,
                        ),
                        children: [
                          if (!isSearching)
                            _CurrentUserStatusHeader(
                              currentUid: currentUser.uid,
                              currentName:
                                  currentProfile?.displayName ??
                                  currentUser.displayName ??
                                  'You',
                              photoUrl: currentProfile?.photoUrl,
                              ownStory: ownStory,
                              onTap: ownStory == null
                                  ? () => _openComposer(
                                      context,
                                      StoryCreationMode.text,
                                    )
                                  : () => _openIsolatedStory(context, ownStory),
                            ),

                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenH.w,
                            ),
                            child: CustomDivider(),
                          ),
                          if (unseenUpdates.isEmpty && viewedUpdates.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xl.h),
                              child: _StoryFeedMessage(
                                icon: isSearching
                                    ? Icons.search_off_rounded
                                    : Icons.auto_stories_outlined,
                                message: isSearching
                                    ? 'No matching stories'
                                    : 'No contact updates',
                              ),
                            ),
                          if (unseenUpdates.isNotEmpty)
                            _StoryUpdateSection(
                              title: 'Recent updates',
                              items: unseenUpdates,
                              initiallyExpanded: true,
                              onStoryTap: (item) => _openFeedStory(
                                context,
                                item: item,
                                items: [...unseenUpdates, ...viewedUpdates],
                                viewedStoryIds: viewedStoryIds,
                              ),
                            ),
                          if (viewedUpdates.isNotEmpty) ...[
                            _StoryUpdateSection(
                              title: 'Viewed updates',
                              items: viewedUpdates,
                              initiallyExpanded: true,
                              onStoryTap: (item) => _openFeedStory(
                                context,
                                item: item,
                                items: viewedUpdates,
                                viewedStoryIds: viewedStoryIds,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.md.w,
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md.h,
            child: FloatingActionButton(
              heroTag: null,
              tooltip: 'Add story',
              onPressed: () => _showCreateStorySheet(context),
              child: Icon(
                Icons.add_rounded,
                color: scheme.surface,
                size: AppSizing.iconSm.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  StoryFeedItem? _ownStory(List<StoryFeedItem> items) {
    for (final item in items) {
      if (item.isOwnStory) return item;
    }
    return null;
  }

  void _openIsolatedStory(BuildContext context, StoryFeedItem item) {
    final activeItem = activeStoryFeedItemAt(item, DateTime.now());
    if (activeItem == null) {
      if (item.isOwnStory) {
        _openComposer(context, StoryCreationMode.text);
      }
      return;
    }

    context.push(
      RouterRoutes.storyViewer.path,
      extra: StoryViewerArgs(feedItem: activeItem),
    );
  }

  void _openFeedStory(
    BuildContext context, {
    required StoryFeedItem item,
    required List<StoryFeedItem> items,
    required Set<String> viewedStoryIds,
  }) {
    final activeItems = activeStoryFeedItemsAt(items, DateTime.now());
    final initialFeedIndex = activeItems.indexWhere(
      (candidate) => candidate.authorUid == item.authorUid,
    );
    if (initialFeedIndex < 0) return;

    context.push(
      RouterRoutes.storyViewer.path,
      extra: StoryViewerArgs.feed(
        feedItems: activeItems,
        initialFeedIndex: initialFeedIndex,
        viewedStoryIds: viewedStoryIds,
      ),
    );
  }

  void _openComposer(BuildContext context, StoryCreationMode initialMode) {
    context.push(
      RouterRoutes.storyComposer.path,
      extra: StoryComposerArgs(initialMode: initialMode),
    );
  }

  Future<void> _showCreateStorySheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              0,
              AppSpacing.md.w,
              AppSpacing.md.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add story',
                  style: sheetContext.text.titleLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                Row(
                  children: [
                    Expanded(
                      child: _StoryCreationOption(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        onTap: () => _selectCreationMode(
                          context,
                          sheetContext,
                          StoryCreationMode.video,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: _StoryCreationOption(
                        icon: Icons.photo_library_outlined,
                        label: 'Photo',
                        onTap: () => _selectCreationMode(
                          context,
                          sheetContext,
                          StoryCreationMode.photo,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: _StoryCreationOption(
                        icon: Icons.text_fields_rounded,
                        label: 'Text',
                        onTap: () => _selectCreationMode(
                          context,
                          sheetContext,
                          StoryCreationMode.text,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: _StoryCreationOption(
                        icon: Icons.mic_none_rounded,
                        label: 'Voice',
                        onTap: () => _selectCreationMode(
                          context,
                          sheetContext,
                          StoryCreationMode.voice,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  void _selectCreationMode(
    BuildContext context,
    BuildContext sheetContext,
    StoryCreationMode mode,
  ) {
    Navigator.pop(sheetContext);
    _openComposer(context, mode);
  }
}

class _StoryCreationOption extends StatelessWidget {
  const _StoryCreationOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySearchField extends StatelessWidget {
  const _StorySearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: 'Search stories',
        hintStyle: context.text.bodySmall.copyWith(
          color: context.text.tertiaryText,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: scheme.onSurface.withValues(alpha: 0.5),
          size: AppSpacing.md.sp,
        ),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: Icon(
                  Icons.close_rounded,
                  color: scheme.onSurfaceVariant,
                  size: AppSizing.iconSm.sp,
                ),
              ),
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.sm.h,
        ),
      ),
      showCursor: true,
      cursorColor: scheme.primary,
    );
  }
}

class _CurrentUserStatusHeader extends StatelessWidget {
  const _CurrentUserStatusHeader({
    required this.currentUid,
    required this.currentName,
    required this.photoUrl,
    required this.ownStory,
    required this.onTap,
  });

  final String currentUid;
  final String currentName;
  final String? photoUrl;
  final StoryFeedItem? ownStory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasStatus = ownStory != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.md.h,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58.r,
                  height: 58.r,
                  padding: hasStatus ? EdgeInsets.all(3.r) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: hasStatus
                        ? Border.all(color: scheme.primary, width: 2.r)
                        : null,
                  ),
                  child: StoryAuthorAvatar(
                    authorUid: currentUid,
                    authorName: currentName,
                    photoUrl: photoUrl,
                    diameter: 58.r,
                  ),
                ),
                if (!hasStatus)
                  Positioned(
                    right: -2.r,
                    bottom: -2.r,
                    child: Container(
                      width: 22.r,
                      height: 22.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                        border: Border.all(color: scheme.surface, width: 2.r),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 15.r,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add status', style: context.text.labelMedium),
                  Gap(AppSpacing.xxs.h),
                  Text(
                    'Disappear after 24 hours',
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
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

class _StoryUpdateSection extends StatelessWidget {
  const _StoryUpdateSection({
    required this.title,
    required this.items,
    required this.initiallyExpanded,
    required this.onStoryTap,
  });

  final String title;
  final List<StoryFeedItem> items;
  final bool initiallyExpanded;
  final ValueChanged<StoryFeedItem> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        childrenPadding: EdgeInsets.zero,
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: context.text.tertiaryText,
        title: Text(
          title,
          style: context.text.labelMedium.copyWith(
            color: context.text.tertiaryText,
          ),
        ),
        children: [
          for (final item in items)
            _StoryFeedTile(item: item, onTap: () => onStoryTap(item)),
        ],
      ),
    );
  }
}

class _StoryFeedTile extends StatelessWidget {
  const _StoryFeedTile({required this.item, required this.onTap});

  final StoryFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.xs.h,
        ),
        child: Row(
          children: [
            Container(
              width: 56.r,
              height: 56.r,
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
              child: StoryAuthorAvatar(
                authorUid: item.authorUid,
                authorName: item.authorName,
                photoUrl: item.authorPhotoUrl,
                diameter: 50.r,
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium,
                  ),
                  SizedBox(height: AppSpacing.xxs.h),
                  Text(
                    _subtitle(item),
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(StoryFeedItem item) {
    final postedAt = item.latestCreatedAt.toLocal();
    final now = DateTime.now();
    final postedDate = DateTime(postedAt.year, postedAt.month, postedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayDifference = today.difference(postedDate).inDays;
    final time = DateFormat('HH:mm').format(postedAt);

    if (dayDifference == 0) return time;
    if (dayDifference == 1) return 'Yesterday, $time';
    return DateFormat('d MMM, HH:mm').format(postedAt);
  }
}

class _StoryFeedMessage extends StatelessWidget {
  const _StoryFeedMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44.r, color: scheme.onSurfaceVariant),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            message,
            style: context.text.bodyMedium.copyWith(
              color: context.text.tertiaryText,
            ),
          ),
        ],
      ),
    );
  }
}
