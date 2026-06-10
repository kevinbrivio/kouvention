import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/chat/views/debug_seeder_view.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';

class ChatHeader extends ConsumerWidget {
  final bool compact;

  const ChatHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatVM = ref.watch(chatListVM);
    final searchVM = ref.watch(searchVMProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact)
                      Text(
                        'Kouvéntion',
                        style: context.text.subheadline1.copyWith(color: scheme.primary),
                      ),
                    if (!compact) Gap(6.h),
                    _buildSearchBox(context, ref, chatVM, searchVM, scheme),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                Gap(AppSpacing.xs.w),
                IconButton(
                  icon: Icon(Icons.bug_report, color: scheme.primary),
                  tooltip: 'Open debug seeder',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebugSeederView()),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        _buildFilterButtons(chatVM, scheme),
        Gap(4.h),
      ],
    );
  }

  Widget _buildSearchBox(
    BuildContext context,
    WidgetRef ref,
    ChatListVM chatVM,
    SearchVM searchVM,
    ColorScheme scheme,
  ) =>
      InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          final chatRooms =
              ref.read(pagedChatListProvider).value ?? const <ChatModel>[];
          searchVM.openSearch(chatRooms);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: scheme.primary, width: 2.w),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w,
            vertical: 10.h,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: AppSpacing.md.sp,
              ),
              Gap(AppSpacing.xs.w),
              Text('Search something...', style: context.text.subDescription3),
            ],
          ),
        ),
      );

  Widget _buildFilterButtons(ChatListVM vm, ColorScheme scheme) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
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
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              vm.setFilter(filter);
            },
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
                style: TextStyle(
                  color: isSelected ? Colors.white : scheme.primary,
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
