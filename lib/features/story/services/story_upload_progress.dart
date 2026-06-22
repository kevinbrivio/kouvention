import 'package:flutter_riverpod/flutter_riverpod.dart';

final storyUploadProgressProvider = StateProvider.autoDispose
    .family<double?, String>((ref, storyId) => null);
