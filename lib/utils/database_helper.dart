import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('teacher_audit.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        main_module TEXT NOT NULL,
        sub_category TEXT NOT NULL,
        title TEXT,
        detailed_description TEXT,
        comments TEXT,
        programme TEXT,
        class_name TEXT,
        division TEXT,
        subject TEXT,
        room_no TEXT,
        is_extra_lecture INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE teaching_subjects (
        id TEXT PRIMARY KEY,
        programme TEXT NOT NULL,
        year TEXT NOT NULL,
        division TEXT,
        subject_name TEXT NOT NULL,
        room_no TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        academic_target_hours REAL NOT NULL DEFAULT 6.4,
        personal_target_hours REAL NOT NULL DEFAULT 2.0,
        is_first_time INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      INSERT INTO user_settings (id, academic_target_hours, personal_target_hours, is_first_time)
      VALUES (1, 6.4, 2.0, 1)
    ''');
  }

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'teacher_audit.db');
  }
}