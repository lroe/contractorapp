import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'dart:io';

/// Manages offline attendance operations
class OfflineAttendanceManager {
  static const String _attendanceBoxName = 'attendance_records';
  static const String _gangsBoxName = 'gangs';
  static const String _workersBoxName = 'workers';

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_attendanceBoxName)) {
      await Hive.openBox<Attendance>(_attendanceBoxName);
    }
    if (!Hive.isBoxOpen(_gangsBoxName)) {
      await Hive.openBox<String>(_gangsBoxName); // Store gang JSON strings
    }
    if (!Hive.isBoxOpen(_workersBoxName)) {
      await Hive.openBox<String>(_workersBoxName); // Store worker JSON strings
    }
  }

  /// Save attendance record locally
  static Future<void> saveAttendanceRecord(Attendance attendance) async {
    final box = Hive.box<Attendance>(_attendanceBoxName);
    await box.put(attendance.id, attendance);
    print('[OfflineAttendance] Saved attendance: ${attendance.id}');
  }

  /// Get attendance records for a specific gang and date
  static List<Attendance> getAttendanceForGang(String gangId, DateTime date) {
    final box = Hive.box<Attendance>(_attendanceBoxName);
    final dateStr = date.toIso8601String().split('T')[0];

    return box.values.where((attendance) {
      final attendanceDateStr = attendance.date.toIso8601String().split('T')[0];
      return attendance.gangId == gangId && attendanceDateStr == dateStr;
    }).toList();
  }

  /// Get unsynced attendance records
  static List<Attendance> getUnsyncedAttendance() {
    final box = Hive.box<Attendance>(_attendanceBoxName);
    return box.values.where((attendance) => !attendance.isSynced).toList();
  }

  /// Mark attendance as synced
  static Future<void> markAttendanceSynced(String attendanceId) async {
    final box = Hive.box<Attendance>(_attendanceBoxName);
    final attendance = box.get(attendanceId);
    if (attendance != null) {
      final syncedAttendance = Attendance(
        id: attendance.id,
        workerId: attendance.workerId,
        gangId: attendance.gangId,
        date: attendance.date,
        status: attendance.status,
        isSynced: true,
        groupPhotoPath: attendance.groupPhotoPath,
      );
      await box.put(attendanceId, syncedAttendance);
      print('[OfflineAttendance] Marked attendance as synced: $attendanceId');
    }
  }

  /// Cache gangs locally (store as JSON strings)
  static Future<void> cacheGangs(String projectId, List<dynamic> gangs) async {
    final box = Hive.box<String>(_gangsBoxName);
    final key = 'project_$projectId';
    await box.put(key, gangs.map((g) => g.toString()).join('|||'));
    print('[OfflineAttendance] Cached ${gangs.length} gangs for project: $projectId');
  }

  /// Get cached gangs for a project
  static List<Map<String, dynamic>> getCachedGangs(String projectId) {
    final box = Hive.box<String>(_gangsBoxName);
    final key = 'project_$projectId';
    final gangsStr = box.get(key);

    if (gangsStr == null || gangsStr.isEmpty) return [];

    try {
      return gangsStr.split('|||').map((gangStr) {
        // This is a simplified approach - in real implementation,
        // you'd want to properly serialize/deserialize JSON
        return {'id': gangStr, 'name': 'Gang $gangStr'};
      }).toList();
    } catch (e) {
      print('[OfflineAttendance] Error parsing cached gangs: $e');
      return [];
    }
  }

  /// Cache workers locally
  static Future<void> cacheWorkers(String gangId, List<dynamic> workers) async {
    final box = Hive.box<String>(_workersBoxName);
    final key = 'gang_$gangId';
    await box.put(key, workers.map((w) => w.toString()).join('|||'));
    print('[OfflineAttendance] Cached ${workers.length} workers for gang: $gangId');
  }

  /// Get cached workers for a gang
  static List<Map<String, dynamic>> getCachedWorkers(String gangId) {
    final box = Hive.box<String>(_workersBoxName);
    final key = 'gang_$gangId';
    final workersStr = box.get(key);

    if (workersStr == null || workersStr.isEmpty) return [];

    try {
      return workersStr.split('|||').map((workerStr) {
        // Simplified approach - proper JSON serialization needed
        return {'id': workerStr, 'name': 'Worker $workerStr'};
      }).toList();
    } catch (e) {
      print('[OfflineAttendance] Error parsing cached workers: $e');
      return [];
    }
  }

  /// Save group photo locally
  static Future<String?> saveGroupPhoto(String gangId, DateTime date, String filePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attendancePhotosDir = Directory('${appDir.path}/attendance_photos');
      if (!attendancePhotosDir.existsSync()) {
        attendancePhotosDir.createSync(recursive: true);
      }

      final dateStr = date.toIso8601String().split('T')[0];
      final filename = 'group_${gangId}_${dateStr}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${attendancePhotosDir.path}/$filename');

      await File(filePath).copy(savedFile.path);
      print('[OfflineAttendance] Saved group photo: $filename');
      return savedFile.path;
    } catch (e) {
      print('[OfflineAttendance] Error saving group photo: $e');
      return null;
    }
  }

  /// Get count of pending attendance records
  static int getPendingCount() {
    return getUnsyncedAttendance().length;
  }

  /// Clear all cached data (useful for logout or data refresh)
  static Future<void> clearCache() async {
    final attendanceBox = Hive.box<Attendance>(_attendanceBoxName);
    final gangsBox = Hive.box<String>(_gangsBoxName);
    final workersBox = Hive.box<String>(_workersBoxName);

    await attendanceBox.clear();
    await gangsBox.clear();
    await workersBox.clear();
    print('[OfflineAttendance] Cache cleared');
  }
}
