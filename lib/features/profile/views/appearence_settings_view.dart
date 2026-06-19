import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/chat/viewmodel/bubble_scheme_provider.dart';
import 'package:kouvention/features/chat/viewmodel/wallpaper_provider.dart';
import 'package:kouvention/features/profile/widgets/settings_tile.dart';
import 'package:kouvention/cores/viewmodels/theme_iris_controller.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';

class AppearanceSettingsView extends ConsumerWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final snapshotKey = ref.read(themeSnapshotKeyProvider);

    return Scaffold(
      appBar: CustomAppBar(
        body: Text('Appearance', style: context.text.appBarTitle),
        onBack: () => context.go('/profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Themes'),
              Gap(AppSpacing.sm.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_6,
                        color: Theme.of(context).colorScheme.primary,
                        size: AppSizing.iconMd.w,
                      ),
                      Gap(AppSpacing.md.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme',
                            style: context.text.bodyMedium.copyWith(
                              fontSize: 13.sp,
                              color: context.text.secondaryText,
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            switch (themeMode) {
                              ThemeMode.system => 'System default',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            },
                            style: context.text.labelSmall.copyWith(
                              color: context.text.tertiaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Gap(AppSpacing.sm.h),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (set) {
                        final controller = ref.read(
                          themeIrisControllerProvider.notifier,
                        );
                        controller.changeTheme(
                          context,
                          set.first,
                          snapshotKey: snapshotKey,
                        );
                      },
                    ),
                  ),
                ],
              ),
              Gap(AppSpacing.xl.h),
              _BubbleStyleSection(),
              Gap(AppSpacing.xl.h),
              _WallpaperSection(),
              Gap(AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: context.text.labelMedium.copyWith(color: context.text.tertiaryText),
  );
}

class _BubbleStyleSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScheme = ref.watch(bubbleSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredPresets = BubbleColorScheme.presets
        .where((s) => s.isDark == isDark)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Customize Chat Bubble'),
        Gap(AppSpacing.sm.h),
        Gap(AppSpacing.md.h),
        Wrap(
          spacing: AppSpacing.xs.w,
          runSpacing: AppSpacing.xs.h,
          children: filteredPresets
              .map(
                (scheme) => _ColorSchemeCard(
                  scheme: scheme,
                  isSelected: scheme.id == currentScheme.id,
                  onTap: () =>
                      ref.read(bubbleSchemeProvider.notifier).select(
                        scheme,
                        isDark ? Brightness.dark : Brightness.light,
                      ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ColorSchemeCard extends StatelessWidget {
  final BubbleColorScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSchemeCard({
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final schemeColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.w,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(
            color: isSelected ? schemeColor : Colors.transparent,
            width: 2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: scheme.receivedBubble,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                Gap(4.w),
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: scheme.sentBubble,
                    borderRadius: BorderRadius.circular(4.r),
                    border: scheme.receivedBubble == Colors.white
                        ? Border.all(color: Colors.grey.shade300)
                        : null,
                  ),
                ),
              ],
            ),
            Gap(4.h),
            Text(
              scheme.name,
              style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(wallpaperProvider.select((s) => s.global));
    final hasUserFile = wallpaper.isFile;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Customize Chat Wallpaper'),
        Gap(AppSpacing.sm.h),
        const _ChatRoomWallpaperPreview(),
        Gap(AppSpacing.sm.h),
        SettingsTile(
          icon: Icons.photo_library_outlined,
          iconColor: scheme.primary,
          title: 'Pick from Gallery',
          subtitle: 'Choose an image from your device',
          onTap: () =>
              ref.read(wallpaperProvider.notifier).pickAndSetFromGallery(),
        ),
        SettingsTile(
          icon: Icons.restart_alt,
          iconColor: scheme.primary,
          title: 'Use Default',
          subtitle: 'Reset to the default wallpaper',
          onTap: () => ref.read(wallpaperProvider.notifier).setDefault(),
        ),
        if (hasUserFile)
          SettingsTile(
            icon: Icons.delete_outline,
            iconColor: Colors.red.shade400,
            title: 'Remove Wallpaper',
            subtitle: 'Hide the wallpaper in all chats',
            onTap: () => ref.read(wallpaperProvider.notifier).setRemoved(),
          ),
      ],
    );
  }
}

/// Mini chat-room mockup that previews the current wallpaper in context.
class _ChatRoomWallpaperPreview extends ConsumerWidget {
  const _ChatRoomWallpaperPreview();

  static const _darkOverlay = ColorFilter.mode(
    Color(0xFF2e2e2e),
    BlendMode.multiply,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(wallpaperProvider.select((s) => s.global));
    final image = wallpaper.image;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 260.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        image: image == null
            ? null
            : DecorationImage(
                image: image,
                fit: BoxFit.cover,
                colorFilter: isDark ? _darkOverlay : null,
              ),
        color: image == null ? Colors.grey.shade200 : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          _PreviewAppBar(),
          Expanded(child: _PreviewMessages()),
          _PreviewInputBar(),
        ],
      ),
    );
  }
}

class _PreviewAppBar extends StatelessWidget {
  const _PreviewAppBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_back, size: AppSpacing.md.w, color: scheme.primary),
          Gap(AppSpacing.sm.w),
          Container(
            width: AppSizing.avatarSm.h,
            height: AppSizing.avatarSm.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: context.text.labelMedium.copyWith(color: scheme.primary),
            ),
          ),
          Gap(AppSpacing.sm.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex',
                  style: context.text.senderName,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Online',
                  style: context.text.labelSmall.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.phone, size: AppSizing.iconSm.w, color: scheme.primary),
          Gap(AppSpacing.xs.w),
          Icon(
            Icons.info_outline,
            size: AppSizing.iconSm.w,
            color: scheme.primary,
          ),
        ],
      ),
    );
  }
}

class _PreviewMessages extends ConsumerWidget {
  const _PreviewMessages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ref.watch(bubbleSchemeProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs.w,
        vertical: AppSpacing.xs.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PreviewBubble(
            scheme: scheme,
            isMe: false,
            text: "Hey, how's the project going?",
            time: '10:42 AM',
          ),
          Gap(6.h),
          _PreviewBubble(
            scheme: scheme,
            isMe: true,
            text: 'Almost done — just polishing the UI',
            time: '10:43 AM',
            showRead: true,
          ),
        ],
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  final BubbleColorScheme scheme;
  final bool isMe;
  final String text;
  final String time;
  final bool showRead;

  const _PreviewBubble({
    required this.scheme,
    required this.isMe,
    required this.text,
    required this.time,
    this.showRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMe ? scheme.sentBubble : scheme.receivedBubble;
    final textColor = context.text.secondaryText;
    final timeColor = context.text.secondaryText.withValues(alpha: 0.2);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 180.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? AppRadius.md.r : 3.r),
            topRight: Radius.circular(isMe ? 3.r : AppRadius.md.r),
            bottomRight: Radius.circular(AppRadius.md.r),
            bottomLeft: Radius.circular(AppRadius.md.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                text,
                style: context.text.labelSmall.copyWith(color: textColor),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: context.text.labelSmall.copyWith(color: timeColor),
                ),
                if (showRead) ...[
                  Gap(3.w),
                  Icon(Icons.done_all, size: 11.sp, color: Colors.blueAccent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewInputBar extends StatelessWidget {
  const _PreviewInputBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: AppSpacing.xs.h,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppSurfaceDark.surfaceInputBar
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.lg.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_emotions_outlined,
                    size: 14.sp,
                    color: scheme.primary,
                  ),
                  Gap(AppSpacing.xs.w),
                  Expanded(
                    child: Text(
                      'Type a message...',
                      style: context.text.typeMessage.copyWith(
                        color: context.text.tertiaryText,
                        fontSize: 9.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.add,
                    size: AppSizing.iconXs,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
          Gap(AppSpacing.xs.w),
          CircleAvatar(
            radius: 16.r,
            backgroundColor: scheme.primary,
            child: Icon(Icons.mic, size: 11.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
