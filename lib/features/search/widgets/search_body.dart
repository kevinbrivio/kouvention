import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/search_result_group_tile.dart';

void _navigateToMessage(BuildContext context, SearchResultModel result) {
  // Close search, navigate to chat room with target message
  context.push(
    '/chats/${result.chatRoomId}',
    // extra: {'targetMessageId': result.messageId},
  );
}

Widget searchBody(BuildContext context, SearchVM vm) {
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
      return ListView.builder(
        itemCount: vm.groups.length,
        itemBuilder: (context, index) => SearchResultGroupTile(
          group: vm.groups[index],
          query: vm.query,
          onResultTap: (result) => _navigateToMessage(context, result),
        ),
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
                style: textTheme.subDescription3,
              ),
          ],
        ),
      );

    case SearchState.error:
      return Center(child: Text(vm.error ?? 'Something went wrong'));
  }
}
