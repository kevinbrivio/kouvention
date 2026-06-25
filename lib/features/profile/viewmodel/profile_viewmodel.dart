import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/message_type.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/media/media_picker_helper.dart';
import 'package:kouvention/features/shared/services/connectivity_service.dart';

import 'package:kouvention/features/shared/services/sync_service.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:kouvention/features/user/viewmodel/presence_notifier.dart';
import 'package:oktoast/oktoast.dart';

final profileVM = ChangeNotifierProvider.autoDispose<ProfileVM>(
  (ref) => ProfileVM(ref),
);

class ProfileVM extends BaseNotifier {
  final UserService _userService;
  final AuthService _authService;
  final MediaPickerHelper _mediaPickerHelper;
  final ConnectivityService _connectivityService;

  UserModel? _user;
  StreamSubscription? _userSubscription;

  ProfileVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _authService = ref.read(authServiceProvider),
      _mediaPickerHelper = ref.read(mediaPickerHelperProvider),
      _connectivityService = ref.read(connectivityServiceProvider);

  bool _isButtonLoading = false;
  int _photoVersion = 0;

  // Getters
  UserModel? get user => _user;
  bool get isButtonLoading => _isButtonLoading;
  int get photoVersion => _photoVersion;

  String get authProviderLabel {
    final providerData = _authService.currentUser?.providerData ?? [];

    for (final info in providerData) {
      if (info.providerId == 'google.com') return 'Connected with Google';
      if (info.providerId == 'apple.com') return 'Connected with Apple';
    }

    return 'Email & Password';
  }

  bool get isGoogleLinked {
    final providerData = _authService.currentUser?.providerData ?? [];
    return providerData.any((info) => info.providerId == 'google.com');
  }

  @override
  FutureOr<void> init() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _userSubscription = _userService
        .streamUser(uid)
        .listen(
          (userModel) {
            final oldUser = _user;
            _user = userModel;
            if (oldUser != null && userModel != null) {
              if (userModel.photoUrl != oldUser.photoUrl) {
                _photoVersion++;
              }
            }
            notifyListeners();
          },
          onError: (e) {
            debugPrint("Profile stream error: $e");
          },
        );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    try {
      isLoading = true;
      _isButtonLoading = true;

      final presence = ref.read(presenceNotifierProvider);
      await presence.signOutWithPresence(_authService);

      // Clear search cache - prevent other user access previous search cache
      final syncService = ref.read(syncServiceProvider);
      await syncService.clearAllData();

      ref.invalidate(chatListVM);
      if (ctx.mounted) {
        ctx.go(RouterRoutes.login.path);
      }
    } catch (e) {

      showToast('Failed to sign out. Please try again');
    } finally {
      isLoading = false;
      _isButtonLoading = false;
    }
  }

  Future<void> changeProfilePhoto(BuildContext context) async {
    final source = await _showImageSourceSheet(context);
    if (source == null) return;

    final picked = await _pickImage(source);
    if (picked == null) return;

    final cropped = await _cropImage(picked.path, context);
    if (cropped == null) return;

    await _uploadAndSave(File(cropped.path));
  }

  Future<ImageSource?> _showImageSourceSheet(BuildContext context) =>
      showModalBottomSheet<ImageSource>(
        context: context,
        useRootNavigator: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

  Future<XFile?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  }

  Future<CroppedFile?> _cropImage(String path, BuildContext context) async =>
      await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColorTokens.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

  Future<void> _uploadAndSave(File file) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final connected = await _connectivityService.isConnected;
    if (!connected) {
      showToast(
        'No internet connection. Please check your network and try again.',
      );
      return;
    }

    isLoading = true;

    try {
      final results = await _mediaPickerHelper.uploadFiles(
        files: [file],
        type: MessageType.image,
      );

      if (results.isEmpty) {
        showToast('Failed to upload photo. Please try again.');
        return;
      }

      await _userService.updateProfile(uid: uid, photoURL: results.first.url);
    } catch (e) {
      debugPrint('Profile photo upload failed: $e');
      showToast('Failed to update photo. Please try again.');
    } finally {
      isLoading = false;
    }
  }

  void navigateToEditName(BuildContext context) {
    if (context.mounted) {
      context.push(RouterRoutes.editName.path, extra: _user?.displayName);
    }
  }

  void navigateToEditStatus(BuildContext context) {
    if (context.mounted) {
      context.push(RouterRoutes.editStatus.path, extra: _user?.bio);
    }
  }
}
