import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'New Group',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
                      color: Colors.white,
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
        Text('Members: ${members.length}', style: context.text.subDescription3),
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
      color: AppColorTokens.formField,
    ),
    child: Form(
      key: _formKey,
      child: CustomTextField(
        inputModel: _groupNameInput,
        hint: 'Group name',
        shakeOnError: true,
        onSubmit: (val) {},
        borderColor: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _buildMemberList(NewGroupChatVM vm) => Row(
    spacing: 32.w,
    children: members
        .map(
          (user) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: AppColorTokens.senderNameColor(user.uid).withValues(alpha: 0.2),
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: context.text.subDescription,
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
}
