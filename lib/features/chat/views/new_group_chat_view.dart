import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.primary,
        ),
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
      if (vm.selectedUsers.isNotEmpty)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: 4.h,
          ),
          child: Text(
            vm.selectedUsers.length == 1
                ? 'Group will include you and 1 other person'
                : 'Group will include you and '
                    '${vm.selectedUsers.length} other people',
            style: context.text.subDescription3.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
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
                child: Text('No users found', style: context.text.subDescription3),
              )
            : _searchController.text.isEmpty
            ? RecentUsersList(
                onUserTap: (user) => vm.toggleUserSelection(user),
                isSelected: (user) => vm.isUserSelected(user),
                showSelection: true,
              )
            : _buildResultsList(),
      ),
      if (vm.selectedUsers.isNotEmpty) _buildCreateGroupButton(),
    ],
  );

  Widget _buildSelectedChips() {
    if (vm.selectedUsers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      child: Wrap(
        spacing: AppSpacing.sm.w,
        runSpacing: AppSpacing.xs.h,
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
                      backgroundColor: AppColorTokens.senderNameColor(
                        user.uid,
                      ).withValues(alpha: 0.2),
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?',
                              style: context.text.subDescription2.copyWith(
                                color: AppColorTokens.senderNameColor(
                                  user.uid,
                                ).withValues(alpha: 0.7),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: AppRadius.sm.r,
                        backgroundColor: scheme.onSurface.withValues(alpha: 0.5),
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
                    style: context.text.subDescription3.copyWith(
                      color: Colors.black,
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

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        decoration: BoxDecoration(
          color: AppColorTokens.searchBar,
          borderRadius: BorderRadius.circular(AppRadius.xl.r),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: vm.onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search people by name',
            hintStyle: context.text.subDescription3,
            border: InputBorder.none,
            icon: Icon(Icons.search, color: scheme.primary, size: 22.sp),
            contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          ),
          style: context.text.subDescription3.copyWith(color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildResultsList() => ListView.builder(
    itemCount: vm.searchResults.length,
    itemBuilder: (context, index) {
      final user = vm.searchResults[index];
      return _buildUserTile(user);
    },
  );

  Widget _buildUserTile(UserModel user) {
    final isSelected = vm.isUserSelected(user);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async => vm.toggleUserSelection(user),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: 10.h,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: scheme.primary.withValues(alpha: 0.2),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: context.text.body2.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: context.text.body2.copyWith(color: Colors.black),
                  ),
                  Gap(2.h),
                  Text(user.email, style: context.text.subDescription3),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? scheme.primary : Colors.grey[400],
              size: AppSizing.iconMd.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGroupButton() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        right: AppSpacing.md.w,
        left: AppSpacing.md.w,
        top: AppSpacing.sm.h,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, -1),
            blurRadius: 8,
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
          ),
        ),
        onPressed: () {
          context.push(RouterRoutes.groupSetup.path, extra: vm.selectedUsers);
        },
        child: Icon(
          Icons.navigate_next_rounded,
          size: AppSizing.iconMd.sp,
          color: Colors.white,
        ),
      ),
    );
  }
}
