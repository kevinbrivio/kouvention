import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/widgets/hidden_app_bar.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/widgets/chatList/chat_header.dart';
import 'package:kouvention/features/chat/widgets/chatList/chat_list_item.dart';
import 'package:kouvention/features/chat/widgets/chatList/chat_list_skeleton.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/search_body.dart';

class ChatListView extends ConsumerStatefulWidget {
  const ChatListView({super.key});

  @override
  ConsumerState<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends ConsumerState<ChatListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent * 0.95) {
      ref.read(chatListVM).fetchOlderChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(chatListVM);
    final searchVm = ref.watch(searchVMProvider);
    final scheme = Theme.of(context).colorScheme;

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
            return _buildSelectionAppBar(context, vm, scheme);
          }
          return HiddenAppBar();
        },
        builder: (context, _) => Stack(
          children: [
            if (searchVm.isActive)
              Column(
                children: [
                  _buildSearchBar(context, searchVm, ref, scheme),
                  Expanded(child: SearchBody()),
                ],
              )
            else
              _buildScreen(context, vm, searchVm, ref),

            if (!searchVm.isActive)
              Positioned(
                right: AppSpacing.md.w,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md.h,
                child: FloatingActionButton(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary.withValues(alpha: 0.1),
                  splashColor: scheme.onPrimary.withValues(alpha: 0.3),
                  onPressed: () {
                    context.push(RouterRoutes.newChat.path);
                  },
                  child: Icon(
                    Icons.edit,
                    color: scheme.surface,
                    size: AppSizing.iconSm.sp,
                  ),
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
    final chats = vm.visibleChats;
    final isChatListReady =
        filteredChatAsync.hasValue && filteredChatAsync.value != null;
    final chatVM = ref.watch(chatListVM);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!vm.isSelectionMode) ChatHeader() else ChatHeader(compact: true),
          Expanded(
            child: filteredChatAsync.when(
              loading: () => const Center(child: ChatListSkeleton()),
              error: (err, stack) => Center(child: ChatListSkeleton()),
              data: (_) {
                if (chats.isEmpty && !isChatListReady) {
                  return const ChatListSkeleton();
                }
                if (chats.isEmpty) Center(child: Text('No conversations yet.'));

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: chats.length + (vm.isLoadingMore ? 1 : 0) + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildFilterButtons(chatVM, scheme);
                    }
                    
                    final chatIndex = index - 1;
                    if (chatIndex == chats.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.md.h,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: AppSpacing.lg.w,
                            height: AppSpacing.lg.w,
                            child: LoadingIndicator(),
                          ),
                        ),
                      );
                    }
                    return ChatListItem(
                      chat: chats[chatIndex],
                      isLastItem: chatIndex == chats.length - 1,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons(ChatListVM vm, ColorScheme scheme) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.screenH.w,
      vertical: AppSpacing.sm.h,
    ),
    child: Row(
      children: ChatFilter.values.map((filter) {
        final isSelected = vm.filter == filter;

        final label = switch (filter) {
          ChatFilter.all => 'All',
          ChatFilter.direct => 'Direct',
          ChatFilter.group => 'Groups',
        };

        return Padding(
          padding: EdgeInsets.only(right: AppSpacing.sm.w),
          child: TapDetector(
            onTap: () => vm.setFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.xs.h,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                label,
                style: context.text.labelMedium.copyWith(
                  color: isSelected ? Colors.white : scheme.primary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildSearchBar(
    BuildContext context,
    SearchVM searchVM,
    WidgetRef ref,
    ColorScheme scheme,
  ) {
    final chatRooms =
        ref.watch(pagedChatListProvider).value ?? const <ChatModel>[];
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.xs.h,
        bottom: AppSpacing.xs.h,
        right: AppSpacing.xs.w,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.primary),
            onPressed: () => searchVM.clearSearch(),
          ),
          Expanded(
            child: SizedBox(
              height: 40.h,
              child: TextFormField(
                autofocus: true,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) => searchVM.onTextChanged(value, chatRooms),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: context.text.bodySmall.copyWith(
                    color: context.text.tertiaryText,
                  ),
                  filled: true,
                  counterStyle: TextStyle(color: scheme.primary),
                  fillColor: scheme.surface.withValues(alpha: 0.1),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                  ),
                ),
                showCursor: true,
                cursorColor: scheme.primary,
              ),
            ),
          ),
          if (searchVM.query.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () => searchVM.clearSearch(),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    ChatListVM vm,
    ColorScheme scheme,
  ) {
    final allPinned = vm.isSelectedChatsPinned;

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.close, color: scheme.primary),
        onPressed: () => vm.clearSelection(),
      ),
      title: Text(
        '${vm.selectedChatIds.length}',
        style: TextStyle(color: scheme.primary, fontSize: 18.sp),
      ),
      actions: [
        IconButton(
          icon: Icon(
            allPinned ? Icons.push_pin_outlined : Icons.push_pin,
            color: scheme.primary,
          ),
          onPressed: () => vm.pinSelectedChats(),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: scheme.primary),
          onPressed: () => _confirmDelete(context, vm),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ChatListVM vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this chat?', style: context.text.headlineSmall),
        content: Text(
          'This chat will be removed from your list. It will reappear if someone sends a new message.',
          style: context.text.labelSmall.copyWith(
            color: context.text.tertiaryText,
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.sm.h,
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: context.text.labelSmall.copyWith(
                    color: context.text.tertiaryText,
                  ),
                ),
              ),
              Gap(AppSpacing.sm.w),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  vm.deleteSelectedChat();
                },
                child: Text(
                  'Delete chat',
                  style: context.text.labelSmall.copyWith(
                    color: context.text.tertiaryText,
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
