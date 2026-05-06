import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';

class SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final ChatRoomVM chatVM; // used for get selected message
  SelectionAppBar({super.key, required this.chatVM});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatSelectionVM);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: vm.clearSelection,
      ),
      title: Text(
        '${vm.selectedCount}',
        style: textTheme.subDescription.copyWith(color: AppColors.primary),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.copy, color: AppColors.primary),
          onPressed: () => vm.copyToClipboard(chatVM),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.primary),
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
