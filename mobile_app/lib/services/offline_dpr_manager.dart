import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'dart:io';

/// Manages offline DPR (Daily Progress Report) operations
class OfflineDPRManager {
  static const String _boxName = 'dpr_reports';

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<DailyProgressReport>(_boxName);
    }
  }

  /// Save DPR report locally
  static Future<void> saveDPRReport(DailyProgressReport report) async {
    final box = Hive.box<DailyProgressReport>(_boxName);
    await box.put(report.id, report);
    print('[OfflineDPR] Saved DPR: ${report.id}');
  }

  /// Get all local DPR reports for a project
  static List<DailyProgressReport> getDPRsByProject(String projectId) {
    final box = Hive.box<DailyProgressReport>(_boxName);
    final reports = box.values
        .where((report) => report.projectId == projectId)
        .toList();
    // Sort by date descending (newest first)
    reports.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    return reports;
  }

  /// Get unsynced DPR reports
  static List<DailyProgressReport> getUnsyncedDPRs() {
    final box = Hive.box<DailyProgressReport>(_boxName);
    return box.values.where((report) => !report.isSynced).toList();
  }

  /// Mark DPR as synced
  static Future<void> markDPRSynced(String dprId, String serverId) async {
    final box = Hive.box<DailyProgressReport>(_boxName);
    final report = box.get(dprId);
    if (report != null) {
      final syncedReport = DailyProgressReport(
        id: serverId, // Use server ID after sync
        projectId: report.projectId,
        supervisorId: report.supervisorId,
        entryDate: report.entryDate,
        remarks: report.remarks,
        linkedTaskId: report.linkedTaskId,
        createdAt: report.createdAt,
        isSynced: true,
        mediaFilePaths: report.mediaFilePaths,
      );
      await box.put(serverId, syncedReport);
      await box.delete(dprId); // Remove local ID
      print('[OfflineDPR] Marked DPR as synced: $serverId');
    }
  }

  /// Get DPR by ID
  static DailyProgressReport? getDPRById(String id) {
    final box = Hive.box<DailyProgressReport>(_boxName);
    return box.get(id);
  }

  /// Delete DPR report
  static Future<void> deleteDPRReport(String id) async {
    final box = Hive.box<DailyProgressReport>(_boxName);
    await box.delete(id);
    print('[OfflineDPR] Deleted DPR: $id');
  }

  /// Get count of pending DPRs
  static int getPendingCount() {
    return getUnsyncedDPRs().length;
  }

  /// Save media files locally (returns local file paths)
  static Future<List<String>> saveMediaFiles(List<String> filePaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dprMediaDir = Directory('${appDir.path}/dpr_media');
    if (!dprMediaDir.existsSync()) {
      dprMediaDir.createSync(recursive: true);
    }

    final savedPaths = <String>[];
    for (var filePath in filePaths) {
      try {
        final file = File(filePath);
        final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final savedFile = File('${dprMediaDir.path}/$filename');
        await file.copy(savedFile.path);
        savedPaths.add(savedFile.path);
        print('[OfflineDPR] Saved media file: $filename');
      } catch (e) {
        print('[OfflineDPR] Error saving media: $e');
      }
    }
    return savedPaths;
  }
}
