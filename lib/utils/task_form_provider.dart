import 'package:flutter/material.dart';
import 'package:task_time/utils/task_entry.dart';

class TaskFormProvider extends ChangeNotifier {
  late MainModule _selectedModule;
  late String _selectedSubCategory;
  late DateTime _startTime;
  late DateTime _endTime;
  late bool _isExtraLecture;

  final TaskEntry? initialTask;
  bool get isEditing => initialTask != null;

  TaskFormProvider({this.initialTask}) {
    if (initialTask != null) {
      _selectedModule = initialTask!.mainModule;
      _selectedSubCategory = initialTask!.subCategory;
      _startTime = initialTask!.startTime;
      _endTime = initialTask!.endTime;
      _isExtraLecture = initialTask!.isExtraLecture;
    } else {
      _selectedModule = MainModule.academic;
      _selectedSubCategory = moduleSubCategories[MainModule.academic]!.first;
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 1));
      _isExtraLecture = false;
    }
  }

  MainModule get selectedModule => _selectedModule;
  String get selectedSubCategory => _selectedSubCategory;
  DateTime get startTime => _startTime;
  DateTime get endTime => _endTime;
  bool get isExtraLecture => _isExtraLecture;

  void toggleExtraLecture(bool value) {
    if (_isExtraLecture != value) {
      _isExtraLecture = value;
      notifyListeners();
    }
  }

  void updateModule(MainModule module) {
    if (_selectedModule != module) {
      _selectedModule = module;
      // Reset subcategory to the first option of the new module
      _selectedSubCategory = moduleSubCategories[module]!.first;
      notifyListeners();
    }
  }

  void updateSubCategory(String subCat) {
    if (_selectedSubCategory != subCat) {
      _selectedSubCategory = subCat;
      notifyListeners();
    }
  }

  void updateTimes(DateTime start, DateTime end) {
    _startTime = start;
    _endTime = end;
    notifyListeners();
  }
}