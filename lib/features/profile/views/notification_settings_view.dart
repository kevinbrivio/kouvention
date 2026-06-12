import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/features/notification/services/notification_sound.dart';
import 'package:kouvention/features/profile/viewmodel/notification_settings_viewmodel.dart';
import 'package:kouvention/features/profile/widgets/settings_tile.dart';
import 'package:kouvention/features/profile/widgets/settings_toggle_tile.dart';

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});

  @override
  Widget build(BuildContext context) => BaseView(
    provider: notificationSettingsVM,
    useGradient: false,
    appBar: (_) => CustomAppBar(
      body: Text('Notifications', style: context.text.appBarTitle),
      onBack: () => context.go(RouterRoutes.profile.path),
    ),
    builder: (context, vm) => _Body(viewmodel: vm),
  );
}

class _Body extends StatefulWidget {
  final NotificationSettingsVM viewmodel;

  const _Body({required this.viewmodel});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with WidgetsBindingObserver {
  final _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _playSound(NotificationSound sound) async {
    await _previewPlayer.stop();
    if (sound.assetPath != null) {
      unawaited(_previewPlayer.play(AssetSource(sound.assetPath!)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.viewmodel.refreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Gap(AppSpacing.lg.h),

          Text(
            'NOTIFICATIONS',
            style: context.text.titleMedium.copyWith(color: context.text.secondaryText)
          ),
          Gap(AppSpacing.sm.h),

          if (!widget.viewmodel.osPermissionGranted) ...[
            _buildPermissionBanner(),
            Gap(AppSpacing.md.h),
          ],

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.25,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsToggleTile(
                icon: Icons.notifications_outlined,
                title: 'Message Notifications',
                subtitle: 'Receive alerts for new messages',
                value: widget.viewmodel.notificationsEnabled,
                onChanged: (_) => widget.viewmodel.toggle(),
              ),
            ),
          ),

          Gap(AppSpacing.xxs.h),

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.25,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsTile(
                icon: Icons.music_note_outlined,
                iconColor: AppColorTokens.primary,
                title: 'Default Sound',
                subtitle: widget.viewmodel.currentSoundDisplayName,
                onTap: () => _showSoundPicker(context),
              ),
            ),
          ),

          Gap(AppSpacing.xxs.h),

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.25,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsTile(
                icon: Icons.groups_outlined,
                iconColor: AppColorTokens.primary,
                title: 'Group Sound',
                subtitle: widget.viewmodel.currentGroupSoundDisplayName,
                onTap: () => _showGroupSoundPicker(context),
              ),
            ),
          ),

          Gap(AppSpacing.xxs.h),

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.25,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsToggleTile(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: Platform.isAndroid
                    ? 'Vibrate on new message'
                    : 'Follows your device system settings',
                value: widget.viewmodel.vibrationEnabled,
                onChanged: (v) => widget.viewmodel.setVibrationEnabled(v),
              ),
            ),
          ),

          Gap(AppSpacing.md.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs.w),
            child: Text(
              widget.viewmodel.osPermissionGranted
                  ? 'You can also manage notification sounds and vibration from your device\'s Settings app.'
                  : 'Notifications are disabled at the system level. Tap "Open Settings" to enable them.',
              style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)
            ),
          ),

          Gap(AppSpacing.xl.h),
        ],
      ),
    ),
  );

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg.r)),
      ),
      builder: (sheetContext) {
        final initialId = widget.viewmodel.currentSoundId;
        var selectedId = initialId;

        return StatefulBuilder(
          builder: (context, setDialogState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        'Notification Sound',
                        style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                      ),
                    ),
                    Gap(AppSpacing.xs.h),
                    ...NotificationSound.bundled.map(
                      (sound) => _SoundTile(
                        label: sound.displayName,
                        isSelected: selectedId == sound.id,
                        onTap: () {
                          _playSound(sound);
                          setDialogState(() => selectedId = sound.id);
                        },
                      ),
                    ),
                    _SoundTile(
                      label: 'System Ringtone',
                      isSelected: selectedId == NotificationSound.systemId,
                      onTap: () => setDialogState(
                        () => selectedId = NotificationSound.systemId,
                      ),
                    ),
                    Gap(AppSpacing.md.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedId != initialId) {
                              widget.viewmodel.selectSound(selectedId);
                            }
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md.r),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGroupSoundPicker(BuildContext context) {
    final initialId = widget.viewmodel.currentGroupSoundId;
    var selectedId = initialId;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setDialogState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        'Group Notification Sound',
                        style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                      ),
                    ),
                    Gap(AppSpacing.xs.h),
                    ListTile(
                      leading: Icon(
                        selectedId == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selectedId == null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                      title: Text(
                        'Default (same as direct)',
                        style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                      ),
                      onTap: () => setDialogState(() => selectedId = null),
                    ),
                    ...NotificationSound.bundled.map(
                      (sound) => _SoundTile(
                        label: sound.displayName,
                        isSelected: selectedId == sound.id,
                        onTap: () {
                          _playSound(sound);
                          setDialogState(() => selectedId = sound.id);
                        },
                      ),
                    ),
                    _SoundTile(
                      label: 'System Ringtone',
                      isSelected: selectedId == NotificationSound.systemId,
                      onTap: () => setDialogState(
                        () => selectedId = NotificationSound.systemId,
                      ),
                    ),
                    Gap(AppSpacing.md.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedId != initialId) {
                              if (selectedId == null) {
                                await widget.viewmodel.selectGroupSound('');
                              } else {
                                await widget.viewmodel.selectGroupSound(selectedId!);
                              }
                            }
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md.r),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildPermissionBanner() => Container(
    padding: EdgeInsets.all(AppSpacing.md.w),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.amber.shade700,
          size: 24.sp,
        ),
        Gap(AppSpacing.sm.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permission Required',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade800,
                ),
              ),
              Gap(AppSpacing.xxs.h),
              Text(
                'Notifications are disabled in your device settings.',
                style: TextStyle(fontSize: 12.sp, color: Colors.brown.shade600),
              ),
            ],
          ),
        ),
        Gap(AppSpacing.xs.w),
        TextButton(
          onPressed: widget.viewmodel.openAppSettings,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
          ),
          child: Text(
            'Open Settings',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SoundTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SoundTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
    ),
    title: Text(label, style: context.text.bodyMedium.copyWith(fontSize: 13.sp, color: context.text.secondaryText)),
    onTap: onTap,
  );
}
