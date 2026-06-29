import 'package:flutter/material.dart';
import 'package:task_time/utils/teaching_subject.dart';
import 'package:task_time/utils/database_helper.dart';

class UserProfileProvider extends ChangeNotifier {
  List<TeachingSubject> _mySubjects = [];
  bool _isFirstTime = true;

  // HARDCODED Academic Target (6 hours 40 mins)
  final double academicTargetHours = 6.67;

  // EDITABLE Personal Target
  double _personalTargetHours = 2.0;

  List<TeachingSubject> get mySubjects => _mySubjects;
  bool get isFirstTime => _isFirstTime;
  double get personalTargetHours => _personalTargetHours;

  UserProfileProvider() {
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final db = await DatabaseHelper.instance.database;

    final settingsMap = await db.query('user_settings', where: 'id = 1');
    if (settingsMap.isNotEmpty) {
      _personalTargetHours = settingsMap.first['personal_target_hours'] as double;
      _isFirstTime = (settingsMap.first['is_first_time'] as int) == 1;
    }

    final subjectsMap = await db.query('teaching_subjects');
    _mySubjects = subjectsMap.map((map) => TeachingSubject(
      id: map['id'] as String,
      programme: map['programme'] as String,
      year: map['year'] as String,
      division: map['division'] as String?,
      subjectName: map['subject_name'] as String,
      roomNo: map['room_no'] as String,
    )).toList();

    notifyListeners();
  }

  // Updated to accept the personal target during onboarding
  Future<void> completeSetup({
    required List<TeachingSubject> subjects,
    required double personalTarget
  }) async {
    final db = await DatabaseHelper.instance.database;

    await db.update('user_settings', {
      'is_first_time': 0,
      'personal_target_hours': personalTarget
    }, where: 'id = 1');

    for (var sub in subjects) {
      await db.insert('teaching_subjects', {
        'id': sub.id,
        'programme': sub.programme,
        'year': sub.year,
        'division': sub.division,
        'subject_name': sub.subjectName,
        'room_no': sub.roomNo,
      });
    }
    await _loadProfileData();
  }

  // NEW: Method to update just the personal target from settings
  Future<void> updatePersonalTarget(double newTarget) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('user_settings', {'personal_target_hours': newTarget}, where: 'id = 1');
    _personalTargetHours = newTarget;
    notifyListeners();
  }

  Future<void> addSubject(TeachingSubject subject) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('teaching_subjects', {
      'id': subject.id,
      'programme': subject.programme,
      'year': subject.year,
      'division': subject.division,
      'subject_name': subject.subjectName,
      'room_no': subject.roomNo,
    });
    await _loadProfileData();
  }

  Future<void> removeSubject(TeachingSubject subject) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('teaching_subjects', where: 'id = ?', whereArgs: [subject.id]);
    await _loadProfileData();
  }
}