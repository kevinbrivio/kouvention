import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';

class ChatHeader extends ConsumerWidget {
  final bool compact;

  const ChatHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatVM = ref.watch(chatListVM);
    final searchVM = ref.watch(searchVMProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact)
                Text(
                  'Kouvention',
                  style: textTheme.subheadline1.copyWith(color: AppColors.primary),
                ),
              if (!compact) Gap(6.h),
              _buildSearchBox(context, ref, chatVM, searchVM),
            ],
          ),
        ),

        // 2. Filter chips (All, Direct, Groups)
        _buildFilterButtons(chatVM),
        Gap(4.h),
      ],
    );
  }

  Widget _buildSearchBox(BuildContext context, WidgetRef ref, ChatListVM chatVM, SearchVM searchVM) => InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        final chatRooms = ref.read(localChatListFromStreamProvider).value ?? [];
        searchVM.openSearch(chatRooms);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.primary, width: 2.w),
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

  // void _openSearchSheet(BuildContext context, ChatListVM chatVM, SearchVM searchVM) => showModalBottomSheet(
  //   context: context,
  //   showDragHandle: false,
  //   enableDrag: false,
  //   isScrollControlled: true,
  //   useRootNavigator: true,
  //   backgroundColor: AppColors.white,
  //   transitionAnimationController: AnimationController(
  //     vsync: Navigator.of(context),
  //     duration: const Duration(milliseconds: 200),
  //   ),
  //   builder: (sheetContext) => SearchOverlay(chats: const []), 
  // );


  Widget _buildFilterButtons(ChatListVM vm) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: ChatFilter.values.map((filter) {
          final isSelected = vm.filter == filter;
          
          // Ini adalah cara yang sangat pintar dan rapi untuk memilih kata!
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
                  color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
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
  }