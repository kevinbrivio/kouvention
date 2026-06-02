import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/viewmodel/chat_room_viewmodel.dart';
import 'package:kouvention/features/user/models/user_model.dart';

class ContactResultTile extends ConsumerWidget {
  final ChatModel chat;
  final String currentUid;
  final String query;
  final VoidCallback onTap;

  const ContactResultTile({
    super.key,
    required this.chat,
    required this.currentUid,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = chat.displayName(currentUid);
    final photoUrl = chat.displayPhotoUrl(currentUid);

    bool showPhoto;
    if (chat.isDirect && photoUrl != null) {
      final otherUid = chat.otherMemberUid(currentUid);
      final otherUser = ref.watch(otherUserStreamProvider(otherUid)).value;
      showPhoto = otherUser?.privacy.showProfilePhoto ?? true;
    } else {
      showPhoto = photoUrl != null;
    }

    return ListTile(
      contentPadding: EdgeInsetsGeometry.symmetric(
        horizontal: 16.w,
        vertical: 6.h,
      ),
      leading: CircleAvatar(
        radius: 24.r,
        backgroundColor: showPhoto
            ? null
            : AppColors.senderNameColor(chat.id).withValues(alpha: 0.3),
        backgroundImage: showPhoto ? NetworkImage(photoUrl!) : null,
        child: !showPhoto
            ? Text(
                name[0].toUpperCase(),
                style: textTheme.senderName.copyWith(
                  color: AppColors.senderNameColor(chat.id),
                ),
              )
            : null,
      ),
      title: _buildHighlightedName(name, context),
      onTap: onTap,
    );
  }

  Widget _buildHighlightedName(String name, BuildContext context) {
    final lowerName = name.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerName.indexOf(lowerQuery);

    if (matchIndex == -1) return Text(name);

    final before = name.substring(0, matchIndex);
    final match = name.substring(matchIndex, matchIndex + query.length);
    final after = name.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        style: textTheme.contactName.copyWith(color: AppColors.black),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x33FFC107),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
