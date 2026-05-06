// ignore_for_file: avoid_print, use_rethrow_when_possible

import '../services/api_service.dart';
import '../services/sync_queue_manager.dart';
import '../services/network_connectivity.dart';
import '../services/offline_dpr_manager.dart';
import '../services/offline_attendance_manager.dart';
import 'dart:async';

/// Handles automatic syncing of offline operations when network is available
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  
  final ApiService _apiService = ApiService();
  final NetworkConnectivity _connectivity = NetworkConnectivity();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  final List<Function(bool)> _syncListeners = [];

  factory BackgroundSyncService() {
    return _instance;
  }

  BackgroundSyncService._internal();

  /// Initialize background sync service
  void initialize() {
    print('[BackgroundSync] Initializing...');
    
    // Listen for connectivity changes
    _connectivity.addListener(_onConnectivityChanged);
    
    // Start periodic sync if online
    _startPeriodicSync();
  }

  /// Called when connectivity status changes
  Future<void> _onConnectivityChanged(bool isOnline) async {
    print('[BackgroundSync] Connectivity changed: isOnline=$isOnline');
    
    if (isOnline && SyncQueueManager.getQueueSize() > 0) {
      print('[BackgroundSync] Network available with ${SyncQueueManager.getQueueSize()} pending operations');
      await performSync();
    }
  }

  /// Start periodic sync check (every 10 seconds while online)
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(seconds: 10), (_) {
      if (_connectivity.isOnline && SyncQueueManager.getQueueSize() > 0 && !_isSyncing) {
        performSync();
      }
    });
  }

  /// Perform sync of all pending operations
  Future<void> performSync() async {
    if (_isSyncing) {
      print('[BackgroundSync] Sync already in progress');
      return;
    }

    _isSyncing = true;
    _notifySyncListeners(true);

    try {
      final operations = SyncQueueManager.getPendingOperations();
      print('[BackgroundSync] Starting sync of ${operations.length} operations');

      int successCount = 0;
      int failureCount = 0;

      for (final operation in operations) {
        try {
          await _syncOperation(operation);
          successCount++;
        } catch (e) {
          print('[BackgroundSync] Error syncing ${operation.type} (${operation.id}): $e');
          
          if (SyncQueueManager.hasExceededMaxRetries(operation)) {
            print('[BackgroundSync] Max retries exceeded for operation ${operation.id}');
            await SyncQueueManager.removeOperation(operation.id);
            failureCount++;
          } else {
            await SyncQueueManager.incrementRetryCount(operation.id);
          }
        }
      }

      print('[BackgroundSync] Sync completed: $successCount success, $failureCount failed');
    } finally {
      _isSyncing = false;
      _notifySyncListeners(false);
    }
  }

  /// Sync a single operation
  Future<void> _syncOperation(SyncOperation operation) async {
    switch (operation.type) {
      case 'dpr':
        await _syncDPROperation(operation);
        break;
      case 'attendance':
        await _syncAttendanceOperation(operation);
        break;
      case 'project_update':
        await _syncProjectUpdateOperation(operation);
        break;
      default:
        throw Exception('Unknown operation type: ${operation.type}');
    }
  }

  /// Sync DPR operation
  Future<void> _syncDPROperation(SyncOperation operation) async {
    final dprData = operation.data;
    print('[BackgroundSync] Syncing DPR: ${operation.id}');

    // Submit DPR to server
    final response = await _apiService.submitDPR(dprData);
    final serverId = response['id'];

    // Mark as synced locally
    await OfflineDPRManager.markDPRSynced(operation.id, serverId.toString());

    // Remove from queue
    await SyncQueueManager.removeOperation(operation.id);
  }

  /// Sync attendance operation
  Future<void> _syncAttendanceOperation(SyncOperation operation) async {
    final attendanceData = operation.data;
    print('[BackgroundSync] Syncing attendance: ${operation.id}');

    try {
      // Submit attendance to server
      await _apiService.submitAttendance(attendanceData);

      // Mark as synced locally
      await OfflineAttendanceManager.markAttendanceSynced(operation.id);

      // Remove from queue
      await SyncQueueManager.removeOperation(operation.id);

      print('[BackgroundSync] Attendance synced successfully: ${operation.id}');
    } catch (e) {
      print('[BackgroundSync] Failed to sync attendance ${operation.id}: $e');
      // Keep in queue for retry
      throw e;
    }
  }

  /// Sync project update operation
  Future<void> _syncProjectUpdateOperation(SyncOperation operation) async {
    print('[BackgroundSync] Syncing project update: ${operation.id}');

    // TODO: Implement project update sync with your API using operation.data
    // For now, just remove from queue
    await SyncQueueManager.removeOperation(operation.id);
  }

  /// Add listener for sync events (true = syncing started, false = syncing stopped)
  void addSyncListener(Function(bool isSyncing) listener) {
    _syncListeners.add(listener);
  }

  /// Remove sync listener
  void removeSyncListener(Function(bool isSyncing) listener) {
    _syncListeners.remove(listener);
  }

  /// Notify listeners of sync state change
  void _notifySyncListeners(bool isSyncing) {
    for (var listener in _syncListeners) {
      listener(isSyncing);
    }
  }

  /// Get current sync status
  bool get isSyncing => _isSyncing;

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    _syncListeners.clear();
  }
}
