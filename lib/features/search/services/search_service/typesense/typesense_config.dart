import 'package:typesense/typesense.dart';

class TypesenseConfig {
  static const host = '10.8.50.65';
  static const int port = 8108;
  static const String apiKey = 'kouvention_api_key_123_xyz';
  static const String collectionName = 'messages';

  static Client createClient() {
    final config = Configuration(
      apiKey,
      nodes: {Node(Protocol.http, host, port: port)},
      connectionTimeout: const Duration(seconds: 5),
    );

    return Client(config);
  }
}
