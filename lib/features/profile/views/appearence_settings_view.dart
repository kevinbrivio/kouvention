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
                            style: AppTextTheme.of(context).subDescription2
                          ),
                          Gap(2.h),
                          Text(
                            switch (themeMode) {
                              ThemeMode.system => 'System default',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            },
                            style: AppTextTheme.of(context).subDescription3
                          ),
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
        _BubblePreview(scheme: currentScheme),
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

class _BubblePreview extends StatelessWidget {
  final BubbleColorScheme scheme;
  const _BubblePreview({required this.scheme});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: 180.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: scheme.sentBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(4.r),
                bottomRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(16.r),
              ),
            ),
            child: Text(
              'Hello! How are you?',
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
            ),
          ),
        ),
        Gap(8.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: 180.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: scheme.receivedBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.r),
                topRight: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(16.r),
              ),
            ),
            child: Text(
              'I\'m good, thanks!',
              style: TextStyle(
                color: scheme.receivedBubble.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
                fontSize: 13.sp,
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
    final wallpaper = ref.watch(wallpaperProvider);
    final hasUserFile = wallpaper.isFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'CUSTOMIZE CHAT WALLPAPER'),
        Gap(12.h),
        _WallpaperPreview(wallpaper: wallpaper),
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

class _WallpaperPreview extends StatelessWidget {
  final WallpaperConfig wallpaper;
  const _WallpaperPreview({required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    final image = wallpaper.image;
    return Container(
      width: double.infinity,
      height: 140.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
        color: image == null ? Colors.grey.shade200 : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: image == null
          ? Center(
              child: Icon(
                Icons.wallpaper,
                size: 40.sp,
                color: Colors.grey.shade400,
              ),
            )
          : null,
    );
  }
}
