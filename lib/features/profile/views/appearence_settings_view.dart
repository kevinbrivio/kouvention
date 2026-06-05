import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/features/chat/models/bubble_color_scheme.dart';
import 'package:kouvention/features/chat/viewmodel/bubble_scheme_provider.dart';
import 'package:kouvention/features/chat/viewmodel/wallpaper_provider.dart';
import 'package:kouvention/features/profile/widgets/settings_tile.dart';
import 'package:kouvention/features/shared/viewmodel/theme_mode_provider.dart';

class AppearanceSettingsView extends ConsumerWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: CustomAppBar(
        body: Text('Appearance', style: AppTextTheme.of(context).appBar),
        onBack: () => context.go('/profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(24.h),
              _SectionHeader(title: 'THEMES'),
              Gap(12.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_6,
                        color: AppColors.primary,
                        size: 24.w,
                      ),
                      Gap(16.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme',
                            style: AppTextTheme.of(context).subDescription2,
                          ),
                          Gap(2.h),
                          Text(switch (themeMode) {
                            ThemeMode.system => 'System default',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          }, style: AppTextTheme.of(context).subDescription3),
                        ],
                      ),
                    ],
                  ),
                  Gap(12.h),
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
                      onSelectionChanged: (set) => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(set.first),
                    ),
                  ),
                ],
              ),
              Gap(32.h),
              _BubbleStyleSection(),
              Gap(32.h),
              _WallpaperSection(),
              Gap(32.h),
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
    style: TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade500,
      letterSpacing: 1.0,
    ),
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
        _SectionHeader(title: 'CUSTOMIZE CHAT BUBBLE'),
        Gap(12.h),
        Gap(16.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: filteredPresets
              .map(
                (scheme) => _ColorSchemeCard(
                  scheme: scheme,
                  isSelected: scheme.id == currentScheme.id,
                  onTap: () =>
                      ref.read(bubbleSchemeProvider.notifier).select(scheme),
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
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
                  color: scheme.sentBubble,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Gap(4.w),
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: scheme.receivedBubble,
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

class _WallpaperSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(wallpaperProvider.select((s) => s.global));
    final hasUserFile = wallpaper.isFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'CUSTOMIZE CHAT WALLPAPER'),
        Gap(12.h),
        const _ChatRoomWallpaperPreview(),
        Gap(12.h),
        SettingsTile(
          icon: Icons.photo_library_outlined,
          iconColor: AppColors.primary,
          title: 'Pick from Gallery',
          subtitle: 'Choose an image from your device',
          onTap: () =>
              ref.read(wallpaperProvider.notifier).pickAndSetFromGallery(),
        ),
        SettingsTile(
          icon: Icons.restart_alt,
          iconColor: AppColors.primary,
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
/// Reactive: updates when wallpaper or bubble scheme changes. Adapts to
/// dark mode with the same overlay used by BaseView.
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
        borderRadius: BorderRadius.circular(12.r),
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
      child: Column(
        children: const [
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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.black.withValues(alpha: 0.85)
            : AppColors.white.withValues(alpha: 0.85),
        // color: AppColors.white.withValues(alpha: 0.85),
        // border: Border(
        //   bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        // ),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_back, size: 16.w, color: AppColors.primary),
          Gap(6.w),
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex',
                  style: AppTextTheme.of(context).senderName,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Online', style: AppTextTheme.of(context).subDescription3.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Icon(Icons.phone, size: 20.w, color: AppColors.primary),
          Gap(10.w),
          Icon(Icons.info_outline, size: 20.w, color: AppColors.primary),
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
    final isLightReceived = !isMe && color.computeLuminance() > 0.5;
    final textColor = isMe
        ? Colors.white
        : (isLightReceived ? Colors.black87 : Colors.white);
    final timeColor = isMe
        ? Colors.white70
        : (isLightReceived ? Colors.grey.shade500 : Colors.white60);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 180.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 12.r : 3.r),
            topRight: Radius.circular(isMe ? 3.r : 12.r),
            bottomRight: Radius.circular(12.r),
            bottomLeft: Radius.circular(12.r),
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
                style: AppTextTheme.of(
                  context,
                ).subDescription3.copyWith(color: textColor),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: AppTextTheme.of(context).subDescription3.copyWith(
                    color: timeColor,
                    fontSize: 9.sp,
                  ),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      // color: Color(0xFF2e2e2e),
      decoration: BoxDecoration(
        color: isDark ? AppColors.black : Colors.transparent,
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
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkInputBarSurface
                    : AppColors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_emotions_outlined,
                    size: 14.sp,
                    color: AppColors.primary,
                  ),
                  Gap(8.w),
                  Expanded(
                    child: Text(
                      'Type a message...',
                      style: AppTextTheme.of(context).typeMessage.copyWith(
                        color: AppColors.grey,
                        fontSize: 11.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.add, size: 14.sp, color: AppColors.primary),
                ],
              ),
            ),
          ),
          Gap(8.w),
          CircleAvatar(
            radius: 15.r,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.mic, size: 14.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
