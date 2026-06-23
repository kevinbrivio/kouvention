import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/custom_divider.dart';
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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppRadius.xl.r,
              backgroundColor: group.chatPhotoUrl == null
                  ? AppColorTokens.senderNameColor(group.chatRoomId)
                  : null,
              backgroundImage: group.chatPhotoUrl != null
                  ? NetworkImage(group.chatPhotoUrl!)
                  : null,
              child: group.chatPhotoUrl == null
                  ? Text(group.chatDisplayName[0].toUpperCase())
                  : null,
            ),
            Gap(AppSpacing.sm.w),
            Expanded(
              child: Text(
                group.chatDisplayName,
                style: context.text.contactName,
              ),
            ),
            Text('${group.results.length}', style: context.text.labelSmall.copyWith(color: context.text.tertiaryText)),
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
      CustomDivider(),
    ],
  );
}
