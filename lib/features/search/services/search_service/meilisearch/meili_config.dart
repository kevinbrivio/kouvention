import 'package:meilisearch/meilisearch.dart';

class MeiliConfig {
  static const String host = 'http://10.8.50.65:7700';
  static const int port = 7700;
  static const String apiKey = 'kouvention_meili_key_xyz';
  static const String indexName = 'messages';

  static MeiliSearchClient createClient() {
    return MeiliSearchClient(host, apiKey);
  }
}
