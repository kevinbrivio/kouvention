import 'package:kouvention/features/search/models/search_result_model.dart';

class SearchResultGroup {
  final String chatRoomId;
  final String chatDisplayName;
  final String? chatPhotoUrl;

  final List<SearchResultModel> results;

  SearchResultGroup({
    required this.chatRoomId,
    required this.chatDisplayName,
    this.chatPhotoUrl,
    required this.results,
  });
}
