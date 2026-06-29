import 'package:flutter/material.dart';
import 'package:task_time/utils/task_entry.dart';
import 'package:task_time/utils/task_repository.dart';

class TaskListProvider extends ChangeNotifier {
  final TaskRepository _repository;

  TaskListProvider(this._repository) {
    loadTasks();
  }

  List<TaskEntry> _tasks = [];
  List<TaskEntry> get tasks => _tasks;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedTasks = await _repository.fetchTasks();
      fetchedTasks.sort((a, b) => b.startTime.compareTo(a.startTime));
      _tasks = fetchedTasks;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(TaskEntry task) async {
    try {
      await _repository.addTask(task);
      await loadTasks(); // Refresh list after adding
    } catch (e) {
      rethrow; // UI will catch this to show a SnackBar
    }
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await loadTasks();
  }

  Future<void> updateTask(TaskEntry task) async {
    try {
      await _repository.updateTask(task);
      await loadTasks(); // Refresh list after updating
    } catch (e) {
      rethrow;
    }
  }
}