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
  @HiveField(5)
  final String? organizationId;
  @HiveField(6)
  final String authProvider;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.organizationId,
    this.authProvider = 'local',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'supervisor',
      organizationId: json['organization_id'],
      authProvider: json['auth_provider'] ?? 'local',
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

  Project({
    required this.id,
    required this.name,
    this.code,
    required this.status,
  });

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

  Worker({
    required this.id,
    required this.name,
    this.phone,
    this.skillType,
    this.gangId,
  });

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
  @HiveField(6)
  final String? groupPhotoPath; // Local path to group photo

  Attendance({
    required this.id,
    required this.workerId,
    required this.gangId,
    required this.date,
    required this.status,
    this.isSynced = false,
    this.groupPhotoPath,
  });
}

@HiveType(typeId: 5)
class ProjectDocument extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String fileUrl;
  @HiveField(3)
  final String? fileType;
  @HiveField(4)
  final String uploadedBy;
  @HiveField(5)
  final DateTime uploadedAt;

  ProjectDocument({
    required this.id,
    required this.name,
    required this.fileUrl,
    this.fileType,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unnamed Document',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'],
      uploadedBy: json['uploaded_by']?.toString() ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : DateTime.now(),
    );
  }
}

@HiveType(typeId: 6)
class DailyProgressReport extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String projectId;
  @HiveField(2)
  final String supervisorId;
  @HiveField(3)
  final DateTime entryDate;
  @HiveField(4)
  final String? remarks;
  @HiveField(5)
  final String? linkedTaskId;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final bool isSynced;
  @HiveField(8)
  final List<String> mediaFilePaths; // Local paths to media files

  DailyProgressReport({
    required this.id,
    required this.projectId,
    required this.supervisorId,
    required this.entryDate,
    this.remarks,
    this.linkedTaskId,
    required this.createdAt,
    this.isSynced = false,
    this.mediaFilePaths = const [],
  });

  factory DailyProgressReport.fromJson(Map<String, dynamic> json) {
    return DailyProgressReport(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      supervisorId: json['supervisor_id']?.toString() ?? '',
      entryDate: json['entry_date'] != null
          ? DateTime.parse(json['entry_date'])
          : DateTime.now(),
      remarks: json['remarks'],
      linkedTaskId: json['linked_task_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isSynced: json['is_synced'] ?? false,
      mediaFilePaths: List<String>.from(json['media_file_paths'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'supervisor_id': supervisorId,
    'entry_date': entryDate.toIso8601String().split('T')[0],
    'remarks': remarks,
    'linked_task_id': linkedTaskId,
    'created_at': createdAt.toIso8601String(),
    'is_synced': isSynced,
    'media_file_paths': mediaFilePaths,
  };
}
