import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
          onPressed: () {
            final selectedMessages = vm.getSelectedMessages(chatVM);
            // filter for me
            debugPrint('---- current uid: ${chatVM.currentUid}');
            final allMine = selectedMessages.every(
              (m) => m.senderId == chatVM.currentUid,
            );
            final anyAlreadyDeleted = selectedMessages.any((m) => m.isDeleted);

            showDialog(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                backgroundColor: AppColors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                title: Text(
                  'Delete ${vm.selectedCount} message${vm.selectedCount > 1 ? 's' : ''}?',
                  style: textTheme.subDescription2.copyWith(
                    color: AppColors.black,
                  ),
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        vm.clearSelection();
                      },
                      child: Text(
                        'Cancel',
                        style: textTheme.subDescription3.copyWith(
                          color: AppColors.primary2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        vm.deleteForMe(chatVM);
                      },
                      child: Text(
                        'Delete for me',
                        style: textTheme.subDescription3.copyWith(
                          color: AppColors.primary2,
                        ),
                      ),
                    ),
                    if (allMine && !anyAlreadyDeleted)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          vm.deleteForEveryone(chatVM);
                        },
                        child: Text(
                          'Delete for everyone',
                          style: textTheme.subDescription3.copyWith(
                            color: AppColors.primary2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
