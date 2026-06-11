import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/custom_app_bar.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/chat/viewmodel/new_chat_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/recent_users_list.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class NewChatView extends StatelessWidget {
  const NewChatView({super.key});

  @override
  Widget build(BuildContext context) => BaseView<NewChatVM>(
    provider: newChatVM,
    useGradient: false,
    appBar: (_) => CustomAppBar(
      onBack: () => context.pop(),
      body: Text('New Chat', style: context.text.appBarTitle),
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchBar(),
        Gap(4.h),
        _buildGroupButton(),
        Flexible(
          child: vm.isSearching
              ? Center(
                  child: SizedBox(
                    width: AppSizing.iconMd.w,
                    height: AppSizing.iconMd.w,
                    child: LoadingIndicator(),
                  ),
                )
              : _searchController.text.isNotEmpty && vm.searchResults.isEmpty
              ? Center(
                  child: Text(
                    'No users found',
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
                  ),
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
    ),
  );

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      child: TextFormField(
        controller: _searchController,
        onChanged: vm.onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search people by name',
          hintStyle: context.text.bodySmall.copyWith(
            color: context.text.tertiaryText,
          ),
          filled: true,
          counterStyle: TextStyle(color: scheme.primary),
          fillColor: scheme.onSurface.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            borderSide: BorderSide(color: scheme.primary),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          prefixIcon: Icon(
            Icons.search,
            size: AppSpacing.lg.sp,
            color: context.text.tertiaryText,
          ),
        ),
        showCursor: true,
        cursorColor: scheme.primary,
        style: context.text.labelSmall.copyWith(
          color: context.text.tertiaryText,
        ),
      ),
    );
  }

  Widget _buildGroupButton() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg.r),
      child: TapDetector(
        onTap: () {
          if (context.mounted) context.push(RouterRoutes.newGroupChat.path);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary,
                child: Icon(
                  Icons.group_add_rounded,
                  size: AppSizing.iconSm.r,
                  color: scheme.surface,
                ),
              ),
              Gap(AppSpacing.sm.w),
              Text(
                'New Group',
                style: context.text.bodyMedium.copyWith(
                  color: context.text.secondaryText,
                ),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final chatId = await vm.createDirectChat(user);
        if (chatId != null && mounted) {
          context.go('/chats/$chatId');
        }
      },
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
                      style: context.text.bodyMedium.copyWith(
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
                    style: context.text.bodyMedium,
                  ),
                  Gap(2.h),
                  Text(
                    user.email,
                    style: context.text.labelSmall.copyWith(
                      color: context.text.tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
