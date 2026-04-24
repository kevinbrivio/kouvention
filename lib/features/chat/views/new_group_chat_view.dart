import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/features/chat/viewmodel/new_group_chat_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/recent_users_list.dart';
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
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _buildSearchBar(),

      _buildSelectedChips(),

      Expanded(
        child: vm.isSearching
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _searchController.text.isNotEmpty && vm.searchResults.isEmpty
            ? Center(
                child: Text('No users found', style: textTheme.subDescription3),
              )
            : _searchController.text.isEmpty
            ? RecentUsersList(
                onUserTap: (user) => vm.toggleUserSelection(user),
                isSelected: (user) => vm.isUserSelected(user),
                showSelection: true,
              )
            : _buildResultsList(),
      ),
      // Create group button — only in group mode with 2+ selected
      if (vm.selectedUsers.length >= 2) _buildCreateGroupButton(),
    ],
  );

  // ── Selected Chips ─────────────────────
  Widget _buildSelectedChips() {
    if (vm.selectedUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 8.h,
        children: vm.selectedUsers.map((user) {
          return GestureDetector(
            onTap: () => vm.toggleUserSelection(user),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22.r,
                      backgroundColor: AppColors.primary2.withValues(
                        alpha: 0.7,
                      ),
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?',
                              style: textTheme.subDescription2,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 8.r,
                        backgroundColor: AppColors.grey,
                        child: Icon(
                          Icons.close,
                          size: 10.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                SizedBox(
                  width: 50.w,
                  child: Text(
                    user.displayName,
                    style: textTheme.subDescription3.copyWith(
                      color: AppColors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: EdgeInsets.all(16.w),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
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
          icon: Icon(Icons.search, color: AppColors.primary, size: 22.sp),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        style: textTheme.subDescription3.copyWith(color: AppColors.black),
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
                      style: textTheme.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
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
                    style: textTheme.body2.copyWith(color: AppColors.black),
                  ),
                  Gap(2.h),
                  Text(user.email, style: textTheme.subDescription3),
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

  // ── Create Group Button ───────────────────────────────
  Widget _buildCreateGroupButton() => Container(
    padding: EdgeInsets.only(
      right: 16.w,
      left: 16.w,
      top: 12.h,
      bottom: MediaQuery.of(context).padding.bottom + 12.h,
    ),
    decoration: BoxDecoration(
      color: Colors.transparent,
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.02),
          offset: Offset(0, -1),
          blurRadius: 8,
        ),
      ],
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      onPressed: () {
        context.push(RouterRoutes.groupSetup.path, extra: vm.selectedUsers);
      },
      child: Icon(
        Icons.navigate_next_rounded,
        size: 24.sp,
        color: AppColors.white,
      ),
    ),
  );
}
