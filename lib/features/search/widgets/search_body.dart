import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/contact_result_tile.dart';
import 'package:kouvention/features/search/widgets/search_result_group_tile.dart';

class SearchBody extends ConsumerWidget {
  SearchBody({super.key});

  void _navigateToMessage(BuildContext context, SearchResultModel result) {
    // Close search, navigate to chat room with target message
    context.push(
      '/chats/${result.chatRoomId}'
      '?scrollTo=${result.messageId}'
      '&sentAt=${result.sentAt.millisecondsSinceEpoch}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(searchVMProvider);
    
    switch (vm.state) {
      case SearchState.idle:
        return Center(
          child: Text(
            'Search across all conversations',
            style: TextStyle(color: Colors.grey),
          ),
        );
  
      case SearchState.searching:
        return const Center(child: CircularProgressIndicator());
  
      case SearchState.results:
        return CustomScrollView(
          slivers: [
            // ===== Contact Header
            if (vm.matchingContacts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Text(
                    'Contacts',
                    style: AppTextTheme.of(context).subDescription.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ContactResultTile(
                    chat: vm.matchingContacts[index],
                    currentUid: vm.currentUid,
                    query: vm.query,
                    onTap: () {
                      final chatId = vm.matchingContacts[index].id;
                      context.push('/chats/$chatId');
                    },
                  ),
                  childCount: vm.matchingContacts.length,
                ),
              ),
              SliverToBoxAdapter(child: CustomDivider()),
            ],
  
            // ===== Messages body
            if (vm.groups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Text(
                    'Messages',
                    style: AppTextTheme.of(context).subDescription.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SearchResultGroupTile(
                    group: vm.groups[index],
                    query: vm.query,
                    currentUid: vm.currentUid,
                    onResultTap: (result) => _navigateToMessage(context, result),
                  ),
                  childCount: vm.groups.length,
                ),
              ),
            ],
          ],
        );
  
      case SearchState.empty:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              if (vm.query.isNotEmpty)
                Text(
                  'No results for "${vm.query}"',
                  style: AppTextTheme.of(context).subDescription3,
                ),
            ],
          ),
        );
  
      case SearchState.error:
        return Center(child: Text(vm.error ?? 'Something went wrong'));
    }
  }
}