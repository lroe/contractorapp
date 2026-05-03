import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator to access localhost
  // Use localhost for iOS Simulator or Desktop
  static const String baseUrl = 'http://localhost:8000'; 

  Future<User> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/?phone=$phone&password=$password'),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<List<dynamic>> getRecentActivity({String? projectId, String? userId}) async {
    String url = '$baseUrl/recent-activity/';
    List<String> params = [];
    if (projectId != null) params.add('project_id=$projectId');
    if (userId != null) params.add('user_id=$userId');
    if (params.isNotEmpty) url += '?' + params.join('&');
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load recent activity');
  }

  Future<List<dynamic>> getAttendanceSummary(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/attendance-summary/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load attendance summary');
  }

  Future<List<dynamic>> getAttendanceDetail(String projectId, String date) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/attendance-detail/?date=$date'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load attendance detail');
  }

  Future<Project> createProject(String name, String ownerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "status": "active",
        "owner_id": ownerId,
      }),
    );

    if (response.statusCode == 200) {
      return Project.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create project: ${response.body}');
    }
  }

  Future<List<Project>> getProjects() async {
    final response = await http.get(Uri.parse('$baseUrl/projects/'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Project>.from(l.map((model) => Project.fromJson(model)));
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<List<Project>> getProjectsForUser(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$userId/projects/'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Project>.from(l.map((model) => Project.fromJson(model)));
    } else {
      throw Exception('Failed to load user projects');
    }
  }

  Future<Map<String, dynamic>> submitDPR(Map<String, dynamic> dprData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dpr/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(dprData),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to submit DPR: ${response.body}');
    }
  }

  Future<List<dynamic>> getProjectDPRs(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/dpr/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project reports');
    }
  }

  Future<void> uploadMedia(String dprId, List<String> filePaths) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/dpr/$dprId/media/'));
    for (var path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', path));
    }
    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload media');
    }
  }

  // Workforce Management

  // Workers
  Future<List<Worker>> getGangWorkers(String gangId) async {
    final response = await http.get(Uri.parse('$baseUrl/gangs/$gangId/workers/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Worker.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load workers');
    }
  }

  Future<void> markAttendance(Map<String, dynamic> attendanceData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(attendanceData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark attendance');
    }
  }

  // Supervisors
  Future<List<User>> getSupervisors() async {
    final response = await http.get(Uri.parse('$baseUrl/supervisors/'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<User>.from(l.map((model) => User.fromJson(model)));
    } else {
      throw Exception('Failed to load supervisors');
    }
  }

  Future<void> assignSupervisor(String projectId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/assign/?user_id=$userId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to assign supervisor: ${response.body}');
    }
  }

  Future<void> unassignSupervisor(String projectId, String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$projectId/unassign/$userId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to unassign supervisor: ${response.body}');
    }
  }

  Future<List<User>> getProjectSupervisors(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/supervisors/'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<User>.from(l.map((model) => User.fromJson(model)));
    } else {
      throw Exception('Failed to load project supervisors');
    }
  }

  Future<List<dynamic>> getRecentReports({int limit = 5}) async {
    final response = await http.get(Uri.parse('$baseUrl/dpr/recent/?limit=$limit'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load recent reports');
    }
  }

  Future<List<dynamic>> getWorkTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/work-types/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load work types');
    }
  }

  Future<void> createWorkType(Map<String, dynamic> workTypeData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/work-types/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(workTypeData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create work type: ${response.body}');
    }
  }

  Future<List<dynamic>> getProjectTasks(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/tasks/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/${taskData['project_id']}/tasks/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(taskData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create task: ${response.body}');
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/$taskId/status/?status=$status'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update task status: ${response.body}');
    }
  }

  Future<List<dynamic>> getTaskDPRs(String taskId) async {
    final response = await http.get(Uri.parse('$baseUrl/tasks/$taskId/dpr/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load task reports');
    }
  }

  Future<void> uploadDPRMedia(String dprId, List<XFile> files) async {
    if (files.isEmpty) return;
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/dpr/$dprId/media/'));
    for (final xfile in files) {
      final file = File(xfile.path);
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final filename = xfile.name.isEmpty ? xfile.path.split('/').last : xfile.name;
      request.files.add(http.MultipartFile(
        'files',
        stream,
        length,
        filename: filename,
      ));
    }
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload media (status ${response.statusCode})');
    }
  }

  Future<List<dynamic>> getDPRMedia(String dprId) async {
    final response = await http.get(Uri.parse('$baseUrl/dpr/$dprId/media/'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load media');
    }
  }

  // Materials
  Future<List<dynamic>> getMaterials() async {
    final response = await http.get(Uri.parse('$baseUrl/materials/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load materials');
  }

  Future<void> createMaterial(Map<String, dynamic> materialData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materials/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(materialData),
    );
    if (response.statusCode != 200) throw Exception('Failed to create material');
  }

  Future<List<dynamic>> getProjectInventory(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/inventory/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load inventory');
  }

  Future<List<dynamic>> getMaterialRequests(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/material-requests/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load material requests');
  }

  Future<void> createMaterialRequest(Map<String, dynamic> requestData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-requests/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestData),
    );
    if (response.statusCode != 200) throw Exception('Failed to create material request');
  }

  Future<void> updateMaterialRequestStatus(String requestId, String status, {String? receivedRemarks}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/material-requests/$requestId/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "status": status,
        if (receivedRemarks != null) "received_remarks": receivedRemarks,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update request status');
    }
  }

  Future<void> uploadMaterialRequestMedia(String requestId, List<String> filePaths) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/material-requests/$requestId/media/'));
    for (var path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', path));
    }
    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload material request media');
    }
  }

  Future<void> logMaterialUsage(Map<String, dynamic> usageData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-usage/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(usageData),
    );
    if (response.statusCode != 200) throw Exception('Failed to log material usage');
  }

  // Bookkeeping
  Future<List<dynamic>> getTransactions(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/transactions/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load transactions');
  }

  Future<void> createTransaction(Map<String, dynamic> txData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(txData),
    );
    if (response.statusCode != 200) throw Exception('Failed to create transaction');
  }

  // Attendance & Gangs
  Future<List<dynamic>> getGangs(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/gangs/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load gangs');
  }

  Future<List<dynamic>> getGangAttendance(String gangId, String date) async {
    final response = await http.get(Uri.parse('$baseUrl/gangs/$gangId/attendance/$date'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load gang attendance');
  }

  Future<void> createGang(Map<String, dynamic> gangData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gangs/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(gangData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create gang: ${response.body}');
    }
  }

  Future<List<dynamic>> getWorkers(String gangId) async {
    final response = await http.get(Uri.parse('$baseUrl/gangs/$gangId/workers/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load workers');
  }

  Future<void> createWorker(Map<String, dynamic> workerData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/workers/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(workerData),
    );
    if (response.statusCode != 200) throw Exception('Failed to create worker');
  }

  Future<void> submitAttendance(Map<String, dynamic> attData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(attData),
    );
    if (response.statusCode != 200) throw Exception('Failed to submit attendance');
  }

  // Project Documents
  Future<List<ProjectDocument>> getProjectDocuments(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/documents/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => ProjectDocument.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load project documents');
    }
  }

  Future<List<ProjectDocument>> uploadProjectDocuments({
    required String projectId,
    required String uploadedBy,
    required List<File> files,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/projects/$projectId/documents/'));
    request.fields['uploaded_by'] = uploadedBy;
    
    for (var file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => ProjectDocument.fromJson(data)).toList();
    } else {
      throw Exception('Failed to upload documents: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDashboardStats(String userId, {String? projectId}) async {
    final url = projectId != null 
        ? '$baseUrl/dashboard-stats/?user_id=$userId&project_id=$projectId'
        : '$baseUrl/dashboard-stats/?user_id=$userId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load dashboard stats');
  }

  // ─── Vendor Methods ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getVendors() async {
    final r = await http.get(Uri.parse('$baseUrl/vendors/'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load vendors');
  }

  Future<Map<String, dynamic>> createVendor(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/vendors/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to create vendor');
  }

  Future<List<dynamic>> getVendorPrices(String materialId) async {
    final r = await http.get(Uri.parse('$baseUrl/vendor-prices/?material_id=$materialId'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load vendor prices');
  }

  Future<void> createVendorPrice(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/vendor-prices/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode != 200) throw Exception('Failed to save vendor price');
  }

  // ─── Purchase Order Methods ─────────────────────────────────────────────────

  Future<List<dynamic>> getPurchaseOrders({String? projectId}) async {
    final url = projectId != null
        ? '$baseUrl/purchase-orders/?project_id=$projectId'
        : '$baseUrl/purchase-orders/';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load purchase orders');
  }

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/purchase-orders/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to create PO: ${r.body}');
  }

  Future<void> updatePOStatus(String poId, String status, {String? approvedBy}) async {
    final body = {'status': status, if (approvedBy != null) 'approved_by': approvedBy};
    final r = await http.patch(Uri.parse('$baseUrl/purchase-orders/$poId/status'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode != 200) throw Exception('Failed to update PO status');
  }

  // ─── BOQ Methods ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getBOQ(String projectId) async {
    final r = await http.get(Uri.parse('$baseUrl/projects/$projectId/boq/'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load BOQ');
  }

  Future<void> upsertBOQItem(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/boq/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode != 200) throw Exception('Failed to save BOQ item');
  }

  // ─── Stock Ledger Methods ─────────────────────────────────────────────────────

  Future<List<dynamic>> getStockLedger(String projectId, {String? materialId}) async {
    final url = materialId != null
        ? '$baseUrl/projects/$projectId/stock-ledger/?material_id=$materialId'
        : '$baseUrl/projects/$projectId/stock-ledger/';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load stock ledger');
  }

  // ─── Transfer Notes ────────────────────────────────────────────────────────

  Future<List<dynamic>> getTransferNotes(String projectId) async {
    final r = await http.get(Uri.parse('$baseUrl/projects/$projectId/transfer-notes/'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load transfer notes');
  }

  Future<void> createTransferNote(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/transfer-notes/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode != 200) throw Exception('Failed to create transfer note');
  }

  Future<void> receiveTransfer(String transferId, String receivedBy) async {
    final r = await http.patch(Uri.parse('$baseUrl/transfer-notes/$transferId/receive?received_by=$receivedBy'));
    if (r.statusCode != 200) throw Exception('Failed to confirm transfer');
  }

  // ─── Waste Logs ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getWasteLogs(String projectId) async {
    final r = await http.get(Uri.parse('$baseUrl/projects/$projectId/waste-logs/'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load waste logs');
  }

  Future<void> logWaste(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/waste-logs/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode != 200) throw Exception('Failed to log waste: ${r.body}');
  }

  // ─── Material Manager Dashboard ────────────────────────────────────────────

  Future<Map<String, dynamic>> getMaterialManagerDashboard() async {
    final r = await http.get(Uri.parse('$baseUrl/material-manager/dashboard/'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load material manager dashboard');
  }

  Future<List<dynamic>> getLowStockAlerts(String ownerId) async {
    final r = await http.get(Uri.parse('$baseUrl/low-stock-alerts/?owner_id=$ownerId'));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to load low stock alerts');
  }

  // ─── User Management ───────────────────────────────────────────────────────

  Future<List<dynamic>> listUsers({String? role}) async {
    final url = role != null ? '$baseUrl/users/?role=$role' : '$baseUrl/users/';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to list users');
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/users/'), headers: _headers, body: jsonEncode(data));
    if (r.statusCode == 200) return json.decode(r.body);
    throw Exception('Failed to create user: ${r.body}');
  }

  Map<String, String> get _headers => {"Content-Type": "application/json"};
}
