import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/tap_detector.dart';
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
                        style: context.text.headlineSmall.copyWith(
                          color: scheme.primary,
                        ),
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
                      MaterialPageRoute(
                        builder: (_) => const DebugSeederView(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(
    BuildContext context,
    WidgetRef ref,
    ChatListVM chatVM,
    SearchVM searchVM,
    ColorScheme scheme,
  ) => TapDetector(
    borderRadius: AppRadius.full.r,
    onTap: () {
      HapticFeedback.selectionClick();
      final chatRooms =
          ref.read(pagedChatListProvider).value ?? const <ChatModel>[];
      searchVM.openSearch(chatRooms);
    },
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: scheme.onSurface.withValues(alpha: 0.5),
            size: AppSpacing.md.sp,
          ),
          Gap(AppSpacing.xs.w),
          Text(
            'Search something...',
            style: context.text.labelMedium.copyWith(
              color: context.text.tertiaryText,
            ),
          ),
        ],
      ),
    ),
  );
}
