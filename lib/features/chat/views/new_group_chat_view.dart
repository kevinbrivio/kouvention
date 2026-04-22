import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/viewmodel/new_group_chat_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class NewGroupChatView extends StatelessWidget {
  const NewGroupChatView({super.key});

  @override
  Widget build(BuildContext context) => BaseView<NewGroupChatVM>(
    provider: newGroupChatVM,
    useGradient: false,
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
    builder: (context, vm) => SafeArea(child: _NewGroupChatBody(vm: vm)),
  );
}

class _NewGroupChatBody extends StatefulWidget {
  final NewGroupChatVM vm;

  _NewGroupChatBody({required this.vm});
  @override
  State<_NewGroupChatBody> createState() => _NewGroupChatBodyState();
}

class _NewGroupChatBodyState extends State<_NewGroupChatBody> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();

  NewGroupChatVM get vm => widget.vm;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _buildSelectedChips(),
      _buildSearchBar(),

      Expanded(
        child: vm.isSearching
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : vm.searchResults.isEmpty
            ? Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'Search for users by name'
                      : 'No users found',
                  style: textTheme.subDescription3,
                ),
              )
            : _buildResultsList(),
      ),
      // Create group button — only in group mode with 2+ selected
      if (vm.selectedUsers.length >= 2) _buildCreateGroupButton(),
    ],
  );

  // ── Selected Chips (group mode) ─────────────────────

  Widget _buildSelectedChips() => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    child: Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: vm.selectedUsers.map((user) {
        return Chip(
          label: Text(user.displayName, style: textTheme.subDescription2),
          deleteIcon: Icon(Icons.close, size: 16.sp),
          onDeleted: () => vm.toggleUserSelection(user),
          backgroundColor: AppColors.primary2.withValues(alpha: 0.4),
          side: BorderSide.none,
        );
      }).toList(),
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: EdgeInsets.all(16.w),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.searchBar,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: vm.onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search people by name',
          hintStyle: textTheme.subDescription3,
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey[400], size: 20.sp),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        style: textTheme.subDescription3,
      ),
    ),
  );

  Widget _buildResultsList() => ListView.builder(
    itemCount: vm.searchResults.length,
    itemBuilder: (context, index) {
      final user = vm.searchResults[index];
      return _buildUserTile(user);
    },
  );

  Widget _buildUserTile(UserModel user) {
    final isSelected = vm.isUserSelected(user);

    return InkWell(
      onTap: () async => vm.toggleUserSelection(user),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22.r,
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

            Gap(16.w),

            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Selection indicator (group mode only)
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : Colors.grey[400],
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  // ── Create Group Button ─────────────────────────────
  Widget _buildCreateGroupButton() => Container(
    padding: EdgeInsets.only(
      left: 16.w,
      right: 16.w,
      top: 12.h,
      bottom: MediaQuery.of(context).padding.bottom + 12.h,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          offset: const Offset(0, -1),
          blurRadius: 4,
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: () => _showGroupNameDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: Text(
        'Create Group (${vm.selectedUsers.length} members)',
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
      ),
    ),
  );

  // ── Group Name Dialog ───────────────────────────────
  void _showGroupNameDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group Name'),
        content: TextField(
          controller: _groupNameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter group name...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(dialogContext);
              _groupNameController.clear();
              final chatId = await vm.createGroupChat(name);
              if (chatId != null && mounted) {
                context.go('/chats/$chatId');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
