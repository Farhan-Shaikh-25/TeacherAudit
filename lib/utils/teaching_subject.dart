import 'package:uuid/uuid.dart';

class TeachingSubject {
  final String id;
  final String programme; // e.g., B.Sc.
  final String year;      // e.g., SY
  final String? division; // Added division field
  final String subjectName;
  final String roomNo;

  TeachingSubject({
    String? id,
    required this.programme,
    required this.year,
    this.division,        // Added to constructor
    required this.subjectName,
    required this.roomNo,
  }) : id = id ?? const Uuid().v4();

  // Helper for the dynamic filtering logic
  String get displayName {
    if (division != null && division!.isNotEmpty) {
      return '$programme - $year $division ($subjectName)';
    }
    return '$programme - $year ($subjectName)';
  }
}