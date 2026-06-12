import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/chat/viewmodel/chat_selection_viewmodel.dart';

class SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String chatId;
  final String currentUid;
  const SelectionAppBar({ super.key, required this.chatId, required this.currentUid });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(chatSelectionVM(chatId));

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
        onPressed: vm.clearSelection,
      ),
      title: Text(
        '${vm.selectedCount}',
        style: context.text.titleMedium.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
          onPressed: vm.copyToClipboard,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.primary),
          onPressed: () {
            final selectedMessages = vm.getSelectedMessages();
            // filter for me
            final allMine = selectedMessages.every((m) => m.senderId == currentUid);
            final anyAlreadyDeleted = selectedMessages.any((m) => m.isDeleted);

            showDialog(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg.r),
                ),
                title: Text(
                  'Delete ${vm.selectedCount} message${vm.selectedCount > 1 ? 's' : ''}?',
                  style: context.text.bodyMedium.copyWith(fontSize: 13.sp, 
                    color: Theme.of(context).colorScheme.onSurface,
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
                        style: context.text.labelSmall.copyWith(color: AppColorTokens.primaryLighter,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        vm.deleteForMe();
                      },
                      child: Text(
                        'Delete for me',
                        style: context.text.labelSmall.copyWith(color: AppColorTokens.primaryLighter,
                        ),
                      ),
                    ),
                    if (allMine && !anyAlreadyDeleted)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          vm.deleteForEveryone();
                        },
                        child: Text(
                          'Delete for everyone',
                          style: context.text.labelSmall.copyWith(color: AppColorTokens.primaryLighter,
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
