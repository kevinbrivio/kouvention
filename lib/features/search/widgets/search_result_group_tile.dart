import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/search/models/search_result_group.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/widgets/search_result_tile.dart';

class SearchResultGroupTile extends StatelessWidget {
  final SearchResultGroup group;
  final String query;
  final String currentUid;
  final void Function(SearchResultModel result) onResultTap;

  const SearchResultGroupTile({
    super.key,
    required this.group,
    required this.query,
    required this.currentUid,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- GROUP HEADER ---
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: group.chatPhotoUrl == null
                  ? AppColors.senderNameColor(group.chatRoomId)
                  : null,
              backgroundImage: group.chatPhotoUrl != null
                  ? NetworkImage(group.chatPhotoUrl!)
                  : null,
              child: group.chatPhotoUrl == null
                  ? Text(group.chatDisplayName[0].toUpperCase())
                  : null,
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                group.chatDisplayName,
                style: AppTextTheme.of(context).contactName,
              ),
            ),
            Text('${group.results.length}', style: AppTextTheme.of(context).subDescription3),
          ],
        ),
      ),
      // --- RESULT TILES ---
      ...group.results.map(
        (result) => SearchResultTile(
          result: result,
          query: query,
          currentUid: currentUid,
          onTap: () => onResultTap(result),
        ),
      ),
      const Divider(),
    ],
  );
}
