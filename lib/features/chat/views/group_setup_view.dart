import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/models/text_input_model.dart';
import 'package:kouvention/cores/widgets/custom_text_field.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/chat/viewmodel/new_group_chat_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class GroupSetupView extends ConsumerStatefulWidget {
  final List<UserModel> selectedUsers;

  GroupSetupView({super.key, required this.selectedUsers});

  @override
  ConsumerState<GroupSetupView> createState() => _GroupSetupViewState();
}

class _GroupSetupViewState extends ConsumerState<GroupSetupView> {
  final _formKey = GlobalKey<FormState>();
  late final TextInputModel _groupNameInput = TextInputModel(
    validator: (value) {
      if (value.trim().isEmpty) return 'Group name is required';

      return null;
    },
  );
  bool _isCreating = false;

  List<UserModel> get members => widget.selectedUsers;

  @override
  void dispose() {
    _groupNameInput.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BaseView<NewGroupChatVM>(
    useGradient: false,
    provider: newGroupChatVM,
    appBar: (vm) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'New Group',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    builder: (context, vm) => SafeArea(
      child: Stack(
        children: [
          _buildScreen(context, vm),
          Positioned(
            bottom: 12.h,
            right: 16.w,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary2,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                final name = _groupNameInput.text;
                if (name.isEmpty) return;

                setState(() => _isCreating = true);
                final chatId = await vm.createGroupChat(name);
                if (chatId != null && mounted) {
                  context.go('/chats/$chatId');
                } else {
                  setState(() => _isCreating = false);
                }
              },
              child: _isCreating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: LoadingIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.check_rounded,
                      color: AppColors.white,
                      size: 24.sp,
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildScreen(BuildContext context, NewGroupChatVM vm) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Gap(8.h),
        // Group Name Textfield
        _buildGroupNameTextField(),

        // Members List
        Text('Members: ${members.length}', style: textTheme.subDescription3),
        Gap(8.h),
        _buildMemberList(vm),
      ],
    ),
  );

  Widget _buildGroupNameTextField() => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 12.h),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.r),
      color: AppColors.formField,
    ),
    child: Form(
      key: _formKey,
      child: CustomTextField(
        inputModel: _groupNameInput,
        hint: 'Group name',
        shakeOnError: true,
        onSubmit: (val) {},
      ),
    ),
  );

  Widget _buildMemberList(NewGroupChatVM vm) => Row(
    spacing: 24.w,
    children: members
        .map(
          (user) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),
                      )
                    : null,
              ),
              Gap(4.h),
              SizedBox(
                width: 50.w,
                child: Text(
                  user.displayName,
                  style: TextStyle(fontSize: 11.sp),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        )
        .toList(),
  );

  // ── Create Group Button ───────────────────────────────
  Widget _buildCreateGroupButton() => Container(
    padding: EdgeInsets.only(
      right: 16.w,
      left: 16.w,
      top: 12.h,
      bottom: MediaQuery.of(context).padding.bottom + 12.h,
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary2,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
      ),
      onPressed: () {},
      child: Icon(Icons.check_rounded, size: 24.sp, color: AppColors.white),
    ),
  );
}
