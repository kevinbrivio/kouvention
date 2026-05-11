import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/search/services/search_service/algolia/algolia_config.dart';
import 'package:kouvention/features/search/services/search_service/algolia/algolia_index_service.dart';
import 'package:kouvention/features/search/services/search_service/meilisearch/meili_config.dart';
import 'package:kouvention/features/search/services/search_service/meilisearch/meili_index_service.dart';
import 'package:kouvention/features/search/services/search_service/typesense/typesense_config.dart';
import 'package:kouvention/features/search/services/search_service/typesense/typesense_index_service.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/search_body.dart';
import 'package:kouvention/features/search/widgets/search_overlay.dart';

class ChatListView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchVm = ref.watch(searchVM);

    return BaseView(
      provider: chatListVM,
      useGradient: false,
      appBar: (vm) {
        if (searchVm.isActive) {
        } else if (vm.isSelectionMode) {
          return _buildSelectionAppBar(context, vm);
        }
        return HiddenAppBar();
      },
      builder: (context, vm) => Stack(
        children: [
          if (searchVm.isActive)
            searchBody(context, searchVm, ref)
          else
            _buildScreen(context, vm, searchVm, ref),

          if (!searchVm.isActive)
            Positioned(
              right: 16.w,
              bottom: MediaQuery.of(context).padding.bottom + 12.h,
              child: FloatingActionButton(
                backgroundColor: AppColors.primary,
                onPressed: () {
                  context.push(RouterRoutes.newChat.path);
                },
                child: Icon(Icons.edit, color: Colors.white, size: 20.sp),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    ChatListVM vm,
    SearchVM searchVM,
    WidgetRef ref,
  ) {
    if (!vm.hasChats) return Center(child: Text('No conversations yet.'));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!vm.isSelectionMode) ...[
            _buildHeader(context, vm, searchVM, ref),
          ] else ...[
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
            ),
          ],

          _buildFilterChips(vm),
          Gap(4.h),

          Expanded(
            child: vm.filteredChats.isEmpty
                ? Center(
                    child: Text(
                      'No ${vm.filter == ChatFilter.direct ? 'direct' : 'group'} chats yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: vm.filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = vm.filteredChats[index];
                      final unread = vm.chatUnreadCount(chat);
                      final lastMessage = chat.lastMessage;
                      final isPinned = chat.isPinnedBy(vm.currentId!);
                      final typing = vm.typingText(chat);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onLongPress: () => vm.selectChat(chat.id),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (vm.isSelectionMode) {
                                vm.selectChat(chat.id);
                              } else {
                                context.push('/chats/${chat.id}');
                              }
                            },
                            splashColor: AppColors.grey.withValues(alpha: 0.2),
                            highlightColor: AppColors.grey.withValues(
                              alpha: 0.1,
                            ),
                            child: Container(
                              color: (vm.selectedChatIds.contains(chat.id))
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              child: Padding(
                                padding: EdgeInsetsGeometry.symmetric(
                                  horizontal: 16.w,
                                  vertical: 12.h,
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          radius: 24.r,
                                          backgroundColor:
                                              AppColors.senderNameColor(
                                                chat.id,
                                              ).withValues(alpha: 0.25),
                                          backgroundImage:
                                              vm.chatPhotoURL(chat) != null
                                              ? NetworkImage(
                                                  vm.chatPhotoURL(chat)!,
                                                )
                                              : null,
                                          child: vm.chatPhotoURL(chat) == null
                                              ? vm.isGroupType(chat)
                                                    ? Icon(
                                                        Icons
                                                            .people_alt_rounded,
                                                        color:
                                                            AppColors.senderNameColor(
                                                              chat.id,
                                                            ).withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      )
                                                    : Text(
                                                        vm
                                                                .chatDisplayName(
                                                                  chat,
                                                                )
                                                                .isNotEmpty
                                                            ? vm
                                                                  .chatDisplayName(
                                                                    chat,
                                                                  )[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: textTheme
                                                            .senderName
                                                            .copyWith(
                                                              fontSize: 18.sp,
                                                              color:
                                                                  AppColors.senderNameColor(
                                                                    chat.id,
                                                                  ).withValues(
                                                                    alpha: 0.7,
                                                                  ),
                                                            ),
                                                      )
                                              : null,
                                        ),

                                        if (vm.selectedChatIds.contains(
                                          chat.id,
                                        ))
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: CircleAvatar(
                                              radius: 8.r,
                                              backgroundColor:
                                                  AppColors.primary,
                                              child: Icon(
                                                Icons.check,
                                                size: 16.sp,
                                                color: AppColors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Gap(12.w),

                                    // Name + Last message
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vm.chatDisplayName(chat),
                                            style: textTheme.senderName
                                                .copyWith(
                                                  color: AppColors.black,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (lastMessage != null)
                                            Text(
                                              typing ?? lastMessage.text,
                                              style: textTheme.subDescription2
                                                  .copyWith(
                                                    color: typing != null
                                                        ? AppColors.primary
                                                        : AppColors.grey,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: true,
                                            ),
                                        ],
                                      ),
                                    ),

                                    Gap(4.w),

                                    // Time + unread badge
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (lastMessage != null)
                                          Text(
                                            DateTimeHelper.formatChatTime(
                                              lastMessage.sentAt,
                                            ),
                                            style: textTheme.subDescription3
                                                .copyWith(
                                                  color: unread > 0
                                                      ? AppColors.primary
                                                      : Colors.grey,
                                                ),
                                          ),
                                        Gap(4.h),
                                        Row(
                                          children: [
                                            if (isPinned)
                                              Icon(
                                                Icons.push_pin_rounded,
                                                color: AppColors.primary,
                                                size: 16.sp,
                                              ),

                                            if (unread > 0) ...[
                                              Gap(6.h),
                                              CircleAvatar(
                                                radius: 10.r,
                                                backgroundColor:
                                                    AppColors.primary,
                                                child: Text(
                                                  '$unread',
                                                  style: textTheme
                                                      .subDescription3
                                                      .copyWith(
                                                        color: AppColors.white,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (index != vm.filteredChats.length - 1)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: Divider(
                                  height: 1,
                                  color: AppColors.grey,
                                  // indent: 64.w,
                                  thickness: 0.2,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ChatListVM vm,
    SearchVM searchVM,
    WidgetRef ref,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kouvention',
          style: textTheme.subheadline1.copyWith(color: AppColors.primary),
        ),

        Gap(6.h),

        _buildSearchField(context, vm, searchVM, ref),
      ],
    ),
  );

  Widget _buildSearchField(
    BuildContext context,
    ChatListVM vm,
    SearchVM searchVM,
    WidgetRef ref,
  ) => InkWell(
    onTap: () async {
      HapticFeedback.selectionClick();
      final client = AlgoliaConfig.adminClient;
      final chatService = ref.read(chatServiceProvider);
      final indexService = AlgoliaIndexService(client, chatService);

      final uid = ref.read(authServiceProvider).currentUser!.uid;
      final chats = ref.read(chatListVM).chats;

      // Index in background
      indexService.indexAllMessages(currentUid: uid, chatRooms: chats);

      // Open search immediately
      searchVM.openSearch();
      _openSearchSheet(context, vm, searchVM);
    },
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        border: BoxBorder.all(color: AppColors.primary, width: 2.w),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.grey, size: 16.sp),
          Gap(8.w),
          Text('Search something...', style: textTheme.subDescription3),
        ],
      ),
    ),
  );

  void _openSearchSheet(
    BuildContext context,
    ChatListVM chatVM,
    SearchVM searchVM,
  ) => showModalBottomSheet(
    context: context,
    showDragHandle: false,
    enableDrag: false,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.white,
    // Smooth curve for the slide-up animation
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (sheetContext) =>
        SearchOverlay(chatVm: chatVM, searchVm: searchVM),
  );

  Widget _buildFilterChips(ChatListVM vm) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Row(
      children: ChatFilter.values.map((filter) {
        final isSelected = vm.filter == filter;
        final label = switch (filter) {
          ChatFilter.all => 'All',
          ChatFilter.direct => 'Direct',
          ChatFilter.group => 'Groups',
        };

        return Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              vm.setFilter(filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    ChatListVM vm,
  ) {
    final allPinned = vm.selectedChats.every(
      (c) => c.isPinnedBy(vm.currentId!),
    );

    return AppBar(
      backgroundColor: AppColors.backdrop,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.primary),
        onPressed: () => vm.clearSection(),
      ),
      title: Text(
        '${vm.selectedChats.length}',
        style: TextStyle(color: AppColors.primary, fontSize: 18.sp),
      ),
      actions: [
        IconButton(
          icon: Icon(
            allPinned ? Icons.push_pin_outlined : Icons.push_pin,
            color: AppColors.primary,
          ),
          onPressed: () => vm.pinSelectedChats(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.primary),
          onPressed: () => _confirmDelete(context, vm),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ChatListVM vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete this chat?',
          style: textTheme.subheadline1.copyWith(color: AppColors.black),
        ),
        content: Text(
          'This chat will be removed from your list. It will reappear if someone sends a new message.',
          style: textTheme.subDescription3,
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: textTheme.subDescription3.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              Gap(12.w),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  vm.deleteSelectedChat();
                },
                child: Text(
                  'Delete chat',
                  style: textTheme.subDescription3.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
