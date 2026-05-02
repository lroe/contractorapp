import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<void> submitDPR(Map<String, dynamic> dprData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dpr/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(dprData),
    );
    if (response.statusCode != 200) {
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

  // Gangs
  Future<List<Gang>> getGangs(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/gangs/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Gang.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load gangs');
    }
  }

  Future<Gang> createGang(String projectId, String name, String supervisorId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gangs/?project_id=$projectId&name=$name&supervisor_id=$supervisorId'),
    );
    if (response.statusCode == 200) {
      return Gang.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create gang');
    }
  }

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
}
