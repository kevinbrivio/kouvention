import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
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
    backgroundColor: AppColors.backdrop,
    useGradient: false,
    appBar: (_) => CustomAppBar(
      body: Text('Notifications', style: textTheme.appBar),
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
    if (sound.isSystemRingtone && sound.androidUri != null) {
      unawaited(_previewPlayer.play(UrlSource(sound.androidUri!)));
    } else if (sound.assetPath != null) {
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
          Gap(24.h),

          Text(
            'NOTIFICATIONS',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 1.0,
            ),
          ),
          Gap(12.h),

          if (!widget.viewmodel.osPermissionGranted) ...[
            _buildPermissionBanner(),
            Gap(16.h),
          ],

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.5,
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

          Gap(4.h),

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsTile(
                icon: Icons.music_note_outlined,
                iconColor: AppColors.primary,
                title: 'Default Sound',
                subtitle: widget.viewmodel.currentSoundDisplayName,
                onTap: () => _showSoundPicker(context),
              ),
            ),
          ),

          Gap(4.h),

          Opacity(
            opacity: widget.viewmodel.osPermissionGranted ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !widget.viewmodel.osPermissionGranted,
              child: SettingsToggleTile(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: 'Vibrate on new message',
                value: widget.viewmodel.vibrationEnabled,
                onChanged: (v) => widget.viewmodel.setVibrationEnabled(v),
              ),
            ),
          ),

          Gap(16.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              widget.viewmodel.osPermissionGranted
                  ? 'You can also manage notification sounds and vibration from your device\'s Settings app.'
                  : 'Notifications are disabled at the system level. Tap "Open Settings" to enable them.',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ),

          Gap(32.h),
        ],
      ),
    ),
  );

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final initialId = widget.viewmodel.currentSoundId;
        var selectedId = initialId;

        return StatefulBuilder(
          builder: (context, setDialogState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Notification Sound',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Gap(8.h),
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
                  if (Platform.isAndroid) ...[
                    Divider(height: 24.h, indent: 20.w, endIndent: 20.w),
                    ListTile(
                      leading: Icon(Icons.audiotrack, color: AppColors.primary),
                      title: Text(
                        'Pick from system ringtones',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await widget.viewmodel.pickSystemRingtone();
                        final uri = widget.viewmodel.prefs.notificationSoundUri;
                        final name = widget.viewmodel.prefs.notificationSoundDisplayName;
                        if (uri != null) {
                          _playSound(NotificationSound.systemRingtone(uri: uri, name: name ?? ''));
                        }
                      },
                    ),
                  ],
                  Gap(16.h),
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionBanner() => Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.amber.shade700,
          size: 24.sp,
        ),
        Gap(12.w),
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
              Gap(4.h),
              Text(
                'Notifications are disabled in your device settings.',
                style: TextStyle(fontSize: 12.sp, color: Colors.brown.shade600),
              ),
            ],
          ),
        ),
        Gap(8.w),
        TextButton(
          onPressed: widget.viewmodel.openAppSettings,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
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
      color: isSelected ? AppColors.primary : Colors.grey.shade400,
    ),
    title: Text(label, style: TextStyle(fontSize: 14.sp)),
    onTap: onTap,
  );
}
