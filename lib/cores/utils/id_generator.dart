import 'dart:math';

class IdGenerator {
  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  static final _random = Random();

  static String generateId() {
    final random = List.generate(
      5,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$random';
  }
}
