import 'package:flutter/material.dart';
import 'package:kouvention/cores/bases/base_view.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

class ChatListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BaseView(provider: chatListVM, builder: _buildScreen);

  Widget _buildScreen(BuildContext context, ChatListVM vm) {
    if (!vm.hasChats) return Center(child: Text('No conversations yet.'));

    return ListView.builder(
      itemCount: vm.chats.length,
      itemBuilder: (context, index) {
        final chat = vm.chats[index];

        return ListTile(
          title: Text(vm.chatDisplayName(chat)),
          subtitle: Text(vm.typingText(chat) ?? chat.lastMessage?.text ?? ''),
        );
      },
    );
  }
}
