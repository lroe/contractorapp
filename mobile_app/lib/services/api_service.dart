import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../config.dart';

class ApiService {

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

  Future<List<dynamic>> getRecentActivity({required String organizationId, String? projectId, String? userId}) async {
    String url = '$baseUrl/recent-activity/?organization_id=$organizationId';
    if (projectId != null) url += '&project_id=$projectId';
    if (userId != null) url += '&user_id=$userId';
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load recent activity');
  }

  Future<List<dynamic>> getAttendanceSummary(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/attendance-summary/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load attendance summary');
  }

  Future<List<Project>> getProjects(String organizationId, {String? userId}) async {
    String url = '$baseUrl/projects/?organization_id=$organizationId';
    if (userId != null) url += '&user_id=$userId';
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Project>.from(l.map((model) => Project.fromJson(model)));
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<Project> createProject(String name, String organizationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "status": "active",
        "organization_id": organizationId,
      }),
    );
    if (response.statusCode == 200) {
      return Project.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create project: ${response.body}');
  }

  Future<Map<String, dynamic>> submitDPR(Map<String, dynamic> dprData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dpr/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(dprData),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to submit DPR: ${response.body}');
  }

  Future<List<dynamic>> getProjectDPRs(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/dpr/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load project reports');
  }

  Future<void> uploadDPRMedia(String dprId, List<XFile> files) async {
    if (files.isEmpty) return;
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/dpr/$dprId/media/'));
    for (final xfile in files) {
      request.files.add(await http.MultipartFile.fromPath('files', xfile.path));
    }
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Failed to upload media');
  }

  Future<List<dynamic>> getWorkTypes(String organizationId) async {
    final response = await http.get(Uri.parse('$baseUrl/work-types/?organization_id=$organizationId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load work types');
  }

  Future<void> createWorkType(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/work-types/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create work type');
  }

  Future<List<dynamic>> getProjectTasks(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/tasks/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load tasks');
  }

  Future<void> createTask(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create task');
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/$taskId/status/?status=$status'),
    );
    if (response.statusCode != 200) throw Exception('Failed to update task status');
  }

  Future<List<dynamic>> getTaskDPRs(String taskId) async {
    final response = await http.get(Uri.parse('$baseUrl/tasks/$taskId/dpr/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load task reports');
  }

  // Attendance & Gangs
  Future<List<dynamic>> getGangs(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/gangs/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load gangs');
  }

  Future<void> createGang(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gangs/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create gang');
  }

  Future<List<dynamic>> getWorkers(String gangId) async {
    final response = await http.get(Uri.parse('$baseUrl/gangs/$gangId/workers/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load workers');
  }

  Future<void> createWorker(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/workers/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
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

  Future<List<dynamic>> getGangAttendance(String gangId, String date) async {
    final response = await http.get(Uri.parse('$baseUrl/gangs/$gangId/attendance/?entry_date=$date'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load gang attendance');
  }

  Future<List<dynamic>> getAttendanceDetail(String projectId, String date) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/attendance-details/?entry_date=$date'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load attendance detail');
  }

  // Documents
  Future<List<ProjectDocument>> getProjectDocuments(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/documents/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => ProjectDocument.fromJson(data)).toList();
    }
    throw Exception('Failed to load project documents');
  }

  Future<void> uploadProjectDocuments({required String projectId, required String uploadedBy, required List<File> files}) async {
    if (files.isEmpty) return;
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/projects/$projectId/documents/'));
    request.fields['uploaded_by'] = uploadedBy;
    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Failed to upload documents');
  }

  Future<Map<String, dynamic>> getDashboardStats(String organizationId, String userId, {String? projectId}) async {
    String url = '$baseUrl/dashboard-stats/?organization_id=$organizationId&user_id=$userId';
    if (projectId != null) url += '&project_id=$projectId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load dashboard stats');
  }

  // Materials (Supervisor views)
  Future<List<dynamic>> getMaterials(String organizationId) async {
    final response = await http.get(Uri.parse('$baseUrl/materials/?organization_id=$organizationId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load materials');
  }

  Future<void> createMaterial(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materials/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
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

  Future<Map<String, dynamic>> createMaterialRequest(Map<String, dynamic> requestData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-requests/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestData),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to create material request');
  }

  Future<void> updateMaterialRequestStatus(String requestId, String status, {String? receivedRemarks}) async {
    String url = '$baseUrl/material-requests/$requestId/status/?status=$status';
    if (receivedRemarks != null) url += '&received_remarks=$receivedRemarks';
    final response = await http.patch(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to update request status');
  }

  Future<void> uploadMaterialRequestMedia(String requestId, List<XFile> files) async {
    if (files.isEmpty) return;
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/material-requests/$requestId/media/'));
    for (final xfile in files) {
      request.files.add(await http.MultipartFile.fromPath('files', xfile.path));
    }
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Failed to upload request media');
  }

  Future<void> logMaterialUsage(Map<String, dynamic> usageData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-usage/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(usageData),
    );
    if (response.statusCode != 200) throw Exception('Failed to log material usage');
  }

  // Finance
  Future<List<dynamic>> getTransactions(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/transactions/'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load transactions');
  }

  Future<void> createTransaction(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to create transaction');
  }

  Future<List<User>> listUsers({String? role, required String organizationId}) async {
    final url = role != null 
        ? '$baseUrl/users/?organization_id=$organizationId&role=$role' 
        : '$baseUrl/users/?organization_id=$organizationId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<User>.from(l.map((model) => User.fromJson(model)));
    }
    throw Exception('Failed to load users');
  }

  Future<void> assignSupervisor(String projectId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/assign/?user_id=$userId'),
    );
    if (response.statusCode != 200) throw Exception('Failed to assign supervisor');
  }

  Future<void> unassignSupervisor(String projectId, String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$projectId/unassign/$userId'),
    );
    if (response.statusCode != 200) throw Exception('Failed to unassign supervisor');
  }

  Future<List<User>> getProjectSupervisors(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/supervisors/'));
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<User>.from(l.map((model) => User.fromJson(model)));
    }
    throw Exception('Failed to load project supervisors');
  }
  Future<void> uploadAttendancePhoto(String gangId, String date, String imagePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/gangs/$gangId/attendance/photo/'));
    request.fields['entry_date'] = date;
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    var response = await request.send();
    if (response.statusCode != 200) throw Exception('Failed to upload attendance photo');
  }
}
