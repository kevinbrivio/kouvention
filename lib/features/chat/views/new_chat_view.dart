import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/chat/viewmodel/new_chat_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/recent_users_list.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class NewChatView extends StatelessWidget {
  const NewChatView({super.key});

  @override
  Widget build(BuildContext context) => BaseView<NewChatVM>(
    provider: newChatVM,
    useGradient: false,
    appBar: (vm) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'New Chat',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    builder: (context, viewmodel) =>
        SafeArea(child: _NewChatBody(viewmodel: viewmodel)),
  );
}

class _NewChatBody extends StatefulWidget {
  final NewChatVM viewmodel;

  const _NewChatBody({required this.viewmodel});

  @override
  State<_NewChatBody> createState() => _NewChatBodyState();
}

class _NewChatBodyState extends State<_NewChatBody> {
  final _searchController = TextEditingController();

  NewChatVM get vm => widget.viewmodel;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Search bar
      _buildSearchBar(),

      Gap(4.h),

      _buildGroupButton(),

      // Results / empty state / loading
      Flexible(
        child: vm.isSearching
            ? Center(
                child: SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: LoadingIndicator(strokeWidth: 2),
                ),
              )
            : _searchController.text.isNotEmpty && vm.searchResults.isEmpty
            ? Center(
                child: Text('No users found', style: textTheme.subDescription3),
              )
            : _searchController.text.isEmpty
            ? RecentUsersList(
                onUserTap: (user) async {
                  final chatId = await vm.createDirectChat(user);
                  if (chatId != null && mounted) {
                    context.go('/chats/$chatId');
                  }
                },
              )
            : _buildResultsList(),
      ),
    ],
  );

  // ── Search Bar ──────────────────────────────────────
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

  // ── Group Toggle ──────────────────────────────────────
  Widget _buildGroupButton() => InkWell(
    onTap: () {
      HapticFeedback.lightImpact();
      if (context.mounted) context.push(RouterRoutes.newGroupChat.path);
    },
    child: Padding(
      padding: EdgeInsets.all(16.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.searchBar,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.group_add_rounded, color: AppColors.white),
            ),
            Gap(12.w),
            Text(
              'New Group',
              style: textTheme.subDescription2.copyWith(color: AppColors.grey),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Results List ────────────────────────────────────
  Widget _buildResultsList() => ListView.builder(
    itemCount: vm.searchResults.length,
    itemBuilder: (context, index) {
      final user = vm.searchResults[index];
      return _buildUserTile(user);
    },
  );

  Widget _buildUserTile(UserModel user) => InkWell(
    onTap: () async {
      final chatId = await vm.createDirectChat(user);
      if (chatId != null && mounted) {
        context.go('/chats/$chatId');
      }
    },
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
        ],
      ),
    ),
  );
}
