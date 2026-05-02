import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('contractor.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE gangs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        project_id TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE workers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        skill_type TEXT,
        gang_id TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        worker_id TEXT NOT NULL,
        gang_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        status TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  // Gang Methods
  Future<void> insertGang(Gang gang) async {
    final db = await instance.database;
    await db.insert('gangs', {
      'id': gang.id,
      'name': gang.name,
      'project_id': gang.projectId,
      'is_synced': 0,
    });
  }

  Future<List<Gang>> getGangs() async {
    final db = await instance.database;
    final result = await db.query('gangs');
    return result.map((json) => Gang.fromJson(json)).toList();
  }

  // Worker Methods
  Future<void> insertWorker(Worker worker) async {
    final db = await instance.database;
    await db.insert('workers', {
      'id': worker.id,
      'name': worker.name,
      'phone': worker.phone,
      'skill_type': worker.skillType,
      'gang_id': worker.gangId,
      'is_synced': 0,
    });
  }

  Future<List<Worker>> getWorkersByGang(String gangId) async {
    final db = await instance.database;
    final result = await db.query('workers', where: 'gang_id = ?', whereArgs: [gangId]);
    return result.map((json) => Worker.fromJson(json)).toList();
  }

  // Attendance Methods
  Future<void> saveAttendance(Map<String, dynamic> attendance) async {
    final db = await instance.database;
    await db.insert('attendance', {
      ...attendance,
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
