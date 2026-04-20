import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // Stream that emits whenever the connectivity status changes
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((res) => !res.contains(ConnectivityResult.none));

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
