import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String phone;
  @HiveField(3)
  final String? email;
  @HiveField(4)
  final String role;

  User({required this.id, required this.name, required this.phone, this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      role: json['role'],
    );
  }
}

@HiveType(typeId: 1)
class Project extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String? code;
  @HiveField(3)
  final String status;

  Project({required this.id, required this.name, this.code, required this.status});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      status: json['status'],
    );
  }
}

@HiveType(typeId: 2)
class Gang extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String projectId;

  Gang({required this.id, required this.name, required this.projectId});

  factory Gang.fromJson(Map<String, dynamic> json) {
    return Gang(
      id: json['id'],
      name: json['name'],
      projectId: json['project_id'],
    );
  }
}

@HiveType(typeId: 3)
class Worker extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String? phone;
  @HiveField(3)
  final String? skillType;
  @HiveField(4)
  final String? gangId;

  Worker({required this.id, required this.name, this.phone, this.skillType, this.gangId});

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      skillType: json['skill_type'],
      gangId: json['gang_id'],
    );
  }
}

@HiveType(typeId: 4)
class Attendance extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String workerId;
  @HiveField(2)
  final String gangId;
  @HiveField(3)
  final DateTime date;
  @HiveField(4)
  final String status;
  @HiveField(5)
  final bool isSynced;

  Attendance({
    required this.id,
    required this.workerId,
    required this.gangId,
    required this.date,
    required this.status,
    this.isSynced = false,
  });
}
