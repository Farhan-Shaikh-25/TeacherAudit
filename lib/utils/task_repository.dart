import 'package:task_time/utils/task_entry.dart';
import 'package:task_time/utils/database_helper.dart';

class TaskRepository {
  bool _isWithin30Days(DateTime date) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return date.isAfter(thirtyDaysAgo);
  }

  Future<List<TaskEntry>> fetchTasks() async {
    final db = await DatabaseHelper.instance.database;
    final thirtyDaysAgoMs = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    // Fetch tasks only from the last 30 days
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'start_time >= ?',
      whereArgs: [thirtyDaysAgoMs],
      orderBy: 'start_time DESC',
    );

    return maps.map((map) => TaskEntry.fromMap(map)).toList();
  }

  Future<void> addTask(TaskEntry task) async {
    if (!_isWithin30Days(task.startTime)) {
      throw Exception("Cannot add tasks older than 30 days.");
    }
    final db = await DatabaseHelper.instance.database;
    await db.insert('tasks', task.toMap());
  }

  Future<void> deleteTask(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTask(TaskEntry updatedTask) async {
    if (!_isWithin30Days(updatedTask.startTime)) {
      throw Exception("Cannot move task to a date older than 30 days.");
    }
    final db = await DatabaseHelper.instance.database;
    await db.update('tasks', updatedTask.toMap(), where: 'id = ?', whereArgs: [updatedTask.id]);
  }
}