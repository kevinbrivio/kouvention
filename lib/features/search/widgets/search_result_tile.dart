import 'package:flutter/material.dart';
import 'package:kouvention/cores/utils/date_time_helper.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResultModel result;
  final String query;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message text with highlighted matching part
          _buildHighlightedText(result.messageText, query, context),
          const SizedBox(height: 4),
          // Sender name and time
          Text(
            '${result.senderName} · ${DateTimeHelper.formatDateMonthYear(result.sentAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  /// Builds a RichText where the matching part is bold/colored.
  Widget _buildHighlightedText(
    String text,
    String query,
    BuildContext context,
  ) {
    // Case-insensitive search for the match position
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    // No match found — just show plain text
    if (matchIndex == -1) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    // Split into three parts: before, match, after
    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x33FFC107), // subtle amber highlight
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
