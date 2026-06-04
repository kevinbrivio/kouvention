import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResultModel result;
  final String query;
  final String currentUid;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.query,
    required this.currentUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.hasMedia || result.messageType == 'text') {
      return _buildTextTile(context);
    }
    return _buildMediaTile(context);
  }

  Widget _buildTextTile(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHighlightedText(result.messageText, query, context),
          Gap(4.h),
          _buildSenderLine(context),
        ],
      ),
    ),
  );

  Widget _buildMediaTile(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMediaLabel(context),
                if (result.messageText.isNotEmpty) ...[
                  Gap(2.h),
                  _buildHighlightedText(result.messageText, query, context),
                ],
                Gap(2.h),
                _buildSenderLine(context),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              width: 48.w,
              height: 48.w,
              child: _buildMediaPreview(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildMediaPreview(BuildContext context) {
    if (result.isImage) {
      final thumb = result.thumbnailUrls?.firstOrNull;
      if (thumb != null) {
        return CachedNetworkImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: Colors.grey[200]),
          errorWidget: (_, _, _) => Icon(Icons.broken_image, color: Colors.grey[400]),
        );
      }
      return Icon(Icons.image, color: Colors.grey[400]);
    }

    if (result.isVideo) {
      final thumb = result.thumbnailUrls?.firstOrNull;
      if (thumb != null) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, _) => Container(color: Colors.grey[200]),
              errorWidget: (_, _, _) => Icon(Icons.broken_image, color: Colors.grey[400]),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 20.w),
            ),
          ],
        );
      }
      return Icon(Icons.videocam, color: Colors.grey[400]);
    }

    if (result.isFile) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Icon(_fileIcon(), color: Colors.grey[600], size: 24.w),
        ),
      );
    }

    return Icon(Icons.attach_file, color: Colors.grey[400]);
  }

  Widget _buildMediaLabel(BuildContext context, ) {
    if (result.isImage) {
      return Text(
        'Photo',
        style: AppTextTheme.of(context).body2.copyWith(color: AppColors.black),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (result.isVideo) {
      return Text(
        'Video',
        style: AppTextTheme.of(context).body2.copyWith(color: AppColors.black),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (result.isFile) {
      return Text(
        result.fileName ?? 'File',
        style: AppTextTheme.of(context).body2.copyWith(color: AppColors.black),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSenderLine(BuildContext context) => Text(
    result.senderId == currentUid
        ? 'You'
        : '${result.senderName} '
              '· ${DateTimeHelper.formatDateMonthYear(result.sentAt)}',
    style: AppTextTheme.of(context).body2.copyWith(color: AppColors.grey),
  );

  Widget _buildHighlightedText(
    String text,
    String query,
    BuildContext context,
  ) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTextTheme.of(context).body2,
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

  IconData _fileIcon() {
    final mime = result.mimeType ?? '';
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('document')) return Icons.description;
    if (mime.contains('excel') || mime.contains('spreadsheet')) return Icons.table_chart;
    if (mime.contains('zip') || mime.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}
