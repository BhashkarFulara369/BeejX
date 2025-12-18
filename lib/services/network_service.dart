import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  // Stream that emits true if offline, false if online
  Stream<bool> get isOffline => _controller.stream;

  NetworkService() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkStatus(results);
    });
  }

  void _checkStatus(List<ConnectivityResult> results) {
    // If results contains none, or is empty, we consider it offline?
    // Actually connectivity_plus returns [ConnectivityResult.none] if disconnected.
    bool isConnected = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet
    );
    _controller.add(!isConnected);
  }

  Future<bool> checkOffline() async {
    final results = await _connectivity.checkConnectivity();
    bool isConnected = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet
    );
    return !isConnected;
  }
  
  void dispose() {
    _controller.close();
  }
}
