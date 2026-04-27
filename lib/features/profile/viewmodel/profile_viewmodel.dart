import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';

final profileVM = ChangeNotifierProvider.autoDispose<ProfileVM>(
  (ref) => ProfileVM(ref),
);

class ProfileVM extends BaseNotifier {
  ProfileVM(super.ref);

  @override
  FutureOr<void> init() {}
  
  // TODO: Logout -> Remove user token (delete in FCM)
  // final fcmService = ref.read(fcmServiceProvider);
  // await fcmService.removeToken();
  // await FirebaseAuth.instance.signOut();
}
