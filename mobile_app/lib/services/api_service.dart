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
      throw Exception('Failed to submit DPR');
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
}
