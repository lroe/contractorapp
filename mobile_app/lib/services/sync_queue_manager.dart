import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

/// Represents a queued operation for sync
class SyncOperation {
  final String id;
  final String type; // 'dpr', 'attendance', 'project_update', etc.
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'],
    type: json['type'],
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Manages operations queued for sync when network is available
class SyncQueueManager {
  static const String _boxName = 'sync_queue';
  static const int _maxRetries = 3;

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  /// Add operation to sync queue
  static Future<void> queueOperation(
    String type,
    Map<String, dynamic> data, {
    String? customId,
  }) async {
    final box = Hive.box<String>(_boxName);
    final id = customId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final operation = SyncOperation(
      id: id,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    await box.put(id, jsonEncode(operation.toJson()));
    print('[SyncQueue] Queued $type operation: $id');
  }

  /// Get all pending operations
  static List<SyncOperation> getPendingOperations() {
    final box = Hive.box<String>(_boxName);
    final operations = <SyncOperation>[];

    for (final jsonStr in box.values) {
      try {
        operations.add(SyncOperation.fromJson(jsonDecode(jsonStr)));
      } catch (e) {
        print('[SyncQueue] Error parsing operation: $e');
      }
    }

    // Sort by creation time (oldest first)
    operations.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return operations;
  }

  /// Get operations by type
  static List<SyncOperation> getOperationsByType(String type) {
    return getPendingOperations().where((op) => op.type == type).toList();
  }

  /// Remove operation from queue after successful sync
  static Future<void> removeOperation(String operationId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(operationId);
    print('[SyncQueue] Removed operation: $operationId');
  }

  /// Update operation retry count
  static Future<void> incrementRetryCount(String operationId) async {
    final box = Hive.box<String>(_boxName);
    final jsonStr = box.get(operationId);
    
    if (jsonStr != null) {
      final operation = SyncOperation.fromJson(jsonDecode(jsonStr));
      final updated = SyncOperation(
        id: operation.id,
        type: operation.type,
        data: operation.data,
        createdAt: operation.createdAt,
        retryCount: operation.retryCount + 1,
      );
      await box.put(operationId, jsonEncode(updated.toJson()));
    }
  }

  /// Check if operation exceeds max retries
  static bool hasExceededMaxRetries(SyncOperation operation) {
    return operation.retryCount >= _maxRetries;
  }

  /// Get queue size
  static int getQueueSize() {
    return Hive.box<String>(_boxName).length;
  }

  /// Clear entire queue
  static Future<void> clearQueue() async {
    final box = Hive.box<String>(_boxName);
    await box.clear();
    print('[SyncQueue] Queue cleared');
  }
}
