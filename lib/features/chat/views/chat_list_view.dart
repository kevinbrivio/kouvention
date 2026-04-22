import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

class ChatListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BaseView(provider: chatListVM, builder: _buildScreen, useGradient: false);

  Widget _buildScreen(BuildContext context, ChatListVM vm) {
    if (!vm.hasChats) return Center(child: Text('No conversations yet.'));

    return ListView.builder(
      itemCount: vm.chats.length,
      itemBuilder: (context, index) {
        final chat = vm.chats[index];

        return ListTile(
          onTap: () => context.push('/chats/${chat.id}'),
          title: Flexible(
            child: Text(
              chat.displayName(chat.id),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Text(
            vm.typingText(chat) ?? chat.lastMessage?.text ?? '',
            style: textTheme.subDescription2.copyWith(color: Colors.grey),
          ),
          trailing: chat.unreadCount.isNotEmpty
              ? CircleAvatar(
                  backgroundColor: AppColors.primary2,
                  radius: 12.r,
                  child: Text(
                    '${chat.unreadCount.length}',
                    style: textTheme.subDescription2.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
