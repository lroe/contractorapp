import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity status
class NetworkConnectivity {
  static final NetworkConnectivity _instance = NetworkConnectivity._internal();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  final List<Function(bool)> _listeners = [];

  factory NetworkConnectivity() {
    return _instance;
  }

  NetworkConnectivity._internal();

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        _notifyListeners(_isOnline);
      }
    });
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Add listener for connectivity changes
  void addListener(Function(bool isOnline) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(Function(bool isOnline) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of connectivity change
  void _notifyListeners(bool isOnline) {
    for (var listener in _listeners) {
      listener(isOnline);
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }
}
