import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/chatList/chat_header.dart';
import 'package:kouvention/features/chat/widgets/chatList/chat_list_item.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/search_body.dart';

class ChatListView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatListVM);
    final searchVm = ref.watch(searchVMProvider);

    return PopScope(
      canPop: !vm.isSelectionMode && !searchVm.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (searchVm.isActive) {
            searchVm.clearSearch();
          } else {
            vm.clearSelection();
          }
        }
      },
      child: BaseView(
        provider: chatListVM,
        useGradient: false,
        appBar: (_) {
          if (searchVm.isActive) {
            return HiddenAppBar();
          }
          if (vm.isSelectionMode) {
            return _buildSelectionAppBar(context, vm);
          }
          return HiddenAppBar();
        },
        builder: (context, _) => Stack(
        children: [
          if (searchVm.isActive)
            Column(
              children: [
                _buildSearchBar(context, searchVm, ref),
                Expanded(child: SearchBody()),
              ],
            )
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
    ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    ChatListVM vm,
    SearchVM searchVM,
    WidgetRef ref,
  ) {
    final filteredChatAsync = ref.watch(filteredChatListProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!vm.isSelectionMode) ...[
            ChatHeader(),
          ] else ...[
            ChatHeader(compact: true),
          ],

          Expanded(
            child: filteredChatAsync.when(
              loading: () => const Center(child: LoadingIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Error loading chats: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (chats) {
                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${vm.filter == ChatFilter.direct ? 'direct' : 'group'} chats yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: chats.length,
                  itemBuilder: (context, index) => ChatListItem(chat: chats[index], isLastItem: index == chats.length + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, SearchVM searchVM, WidgetRef ref) {
    final chatRooms = ref.watch(localChatListFromStreamProvider).value ?? [];
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8.h,
        bottom: 8.h,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => searchVM.clearSearch(),
          ),
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: TextField(
                autofocus: true,
                onChanged: (value) => searchVM.onTextChanged(value, chatRooms),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: AppColors.grey, fontSize: 14.sp),
                  filled: true,
                  fillColor: AppColors.grey.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                ),
              ),
            ),
          ),
          if (searchVM.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.grey),
              onPressed: () => searchVM.clearSearch(),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    ChatListVM vm,
  ) {
    final allPinned = vm.isSelectedChatsPinned;

    return AppBar(
      backgroundColor: AppColors.backdrop,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.primary),
        onPressed: () => vm.clearSelection(),
      ),
      title: Text(
        '${vm.selectedChatIds.length}',
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
