import 'package:algoliasearch/algoliasearch.dart';

class AlgoliaConfig {
  static const String appId = 'UFORMFF5UB';
  static const String adminKey = '7b55e35a847324577efc08997e842a2e';
  static const String searchKey = '227bcb2cc5e614f724ce398a59f1c7bd';
  static const String indexName = 'messages';

  // For indexing (admin permissions)
  static SearchClient get adminClient =>
      SearchClient(appId: appId, apiKey: adminKey);

  // For searching (read-only, safe for client)
  static SearchClient get searchClient =>
      SearchClient(appId: appId, apiKey: searchKey);
}
