import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manage encryption key for SQLite database.
/// This key will be generated ONCE when running the app
/// If the key is missing/gone, old database will be removed
/// And user will use new database.
class DbKeyManager {
  static const _storage = FlutterSecureStorage();
  static const _keyName = '_sqlite_encryption_key_';

  static Future<String> getOrCreateKey() async {
    // 1. Load the old key (if exist)
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null) return existingKey;

    // 2. No old key -> Generate a new one
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    // 3. Convert bytes to base64 String (SQLite pragma accepts string)
    final newKey = base64Url.encode(bytes);

    // 4. Save in storage
    await _storage.write(key: _keyName, value: newKey);

    return newKey;
  }

  
}
