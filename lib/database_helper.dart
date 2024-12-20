import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'models/todo_task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'app_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            time TEXT,
            location TEXT,
            description TEXT,
            category TEXT,
            date TEXT
          )
        ''');
        db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT,
            deadline TEXT,
            isCompleted INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> row, int id) async {
    final db = await database;
    return await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // Insert a new task
Future<int> insertTask(ToDoTask task) async {
  return await insert('tasks', task.toMap());
}

// Fetch all tasks
Future<List<ToDoTask>> fetchTasks() async {
  final maps = await queryAll('tasks');
  return List.generate(
    maps.length,
    (i) => ToDoTask.fromMap(maps[i]),
  );
}

// Update a task
Future<int> updateTask(ToDoTask task) async {
  return await update('tasks', task.toMap(), task.id!);
}

Future<void> updateTaskCompletion(int id, bool isCompleted) async {
  final db = await database;
  await db.update(
    'tasks', // Nama tabel
    {'isCompleted': isCompleted ? 1 : 0}, // Perbarui nilai isCompleted
    where: 'id = ?', // Cari berdasarkan ID
    whereArgs: [id],
  );
}

Future<void> deleteTask(int id) async {
  final db = await database;
  await db.delete(
    'tasks', // Nama tabel
    where: 'id = ?', // Hapus berdasarkan ID
    whereArgs: [id],
  );
}


}