import 'package:uuid/uuid.dart';

enum MainModule { academic, research, otherWork, personal }

extension MainModuleExtension on MainModule {
  String get displayName {
    switch (this) {
      case MainModule.academic: return '1. Academic';
      case MainModule.research: return '2. Research';
      case MainModule.otherWork: return '3. Other Work';
      case MainModule.personal: return '4. Personal';
    }
  }
}

// Map the exact wireframe categories
const Map<MainModule, List<String>> moduleSubCategories = {
  MainModule.academic: [
    'Teaching', 'Administrative Responsibilities', 'Examination & Evaluation',
    'Student Committees', 'Institutional Governance', 'Organizing Seminar/Workshop'
  ],
  MainModule.research: [
    'Research Paper', 'New Course / ICT Creation', 'Guidance (PhD/PG)',
    'Research Project', 'Presentation/Invited Lecture', 'Attended Courses'
  ],
  MainModule.otherWork: [
    'Lecture Preparation', 'Departmental Work', 'IQAC / NAAC', 'Meetings', 'Other'
  ],
  MainModule.personal: [
    'Physical', 'Mental', 'Economic', 'Family', 'Other'
  ],
};

class TaskEntry {
  final String id;
  final DateTime startTime;
  final DateTime endTime;

  final MainModule mainModule;
  final String subCategory;

  final String? title;
  final String? detailedDescription;
  final String? comments;

  final String? programme;
  final String? className;
  final String? division;
  final String? subject;
  final String? roomNo;
  final bool isExtraLecture;

  TaskEntry({
    String? id,
    required this.startTime,
    required this.endTime,
    required this.mainModule,
    required this.subCategory,
    this.title,
    this.detailedDescription,
    this.comments,
    this.programme,
    this.className,
    this.division,
    this.subject,
    this.roomNo,
    this.isExtraLecture = false
  }) : id = id ?? const Uuid().v4();

  Duration get duration => endTime.difference(startTime);

  bool get isAcademicTarget => mainModule != MainModule.personal;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'main_module': mainModule.name,
      'sub_category': subCategory,
      'title': title,
      'detailed_description': detailedDescription,
      'comments': comments,
      'programme': programme,
      'class_name': className,
      'division': division,
      'subject': subject,
      'room_no': roomNo,
      'is_extra_lecture': isExtraLecture ? 1:0
    };
  }

  factory TaskEntry.fromMap(Map<String, dynamic> map) {
    return TaskEntry(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      mainModule: MainModule.values.firstWhere(
            (e) => e.name == map['main_module'],
        orElse: () => MainModule.otherWork,
      ),
      subCategory: map['sub_category'] as String,
      title: map['title'] as String?,
      detailedDescription: map['detailed_description'] as String?,
      comments: map['comments'] as String?,
      programme: map['programme'] as String?,
      className: map['class_name'] as String?,
      division: map['division'] as String?,
      subject: map['subject'] as String?,
      roomNo: map['room_no'] as String?,
      isExtraLecture: map['is_extra_lecture'] == 1
    );
  }
}