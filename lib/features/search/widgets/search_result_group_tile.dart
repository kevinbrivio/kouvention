import 'package:flutter/material.dart';
import 'package:kouvention/features/search/models/search_result_group.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/widgets/search_result_tile.dart';

class SearchResultGroupTile extends StatelessWidget {
  final SearchResultGroup group;
  final String query;
  final void Function(SearchResultModel result) onResultTap;

  const SearchResultGroupTile({
    super.key,
    required this.group,
    required this.query,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- GROUP HEADER ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: group.chatPhotoUrl != null
                    ? NetworkImage(group.chatPhotoUrl!)
                    : null,
                child: group.chatPhotoUrl == null
                    ? Text(group.chatDisplayName[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.chatDisplayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                '${group.results.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
        // --- RESULT TILES ---
        ...group.results.map(
          (result) => SearchResultTile(
            result: result,
            query: query,
            onTap: () => onResultTap(result),
          ),
        ),
        const Divider(),
      ],
    );
}