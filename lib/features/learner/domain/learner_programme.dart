import 'learner_enums.dart';

/// A programme the learner is enrolled on.
class LearnerProgramme {
  const LearnerProgramme({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.imageUrl,
    required this.durationLabel,
    required this.deliveryMode,
    required this.status,
    required this.courseIds,
    this.faculty = const [],
    this.startDate,
    this.expectedCompletion,
    this.cpdPoints = 0,
    this.certificateId,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final String imageUrl;
  final String durationLabel;
  final String deliveryMode;
  final ProgrammeStatus status;
  final List<String> courseIds;
  final List<String> faculty;
  final DateTime? startDate;
  final DateTime? expectedCompletion;
  final int cpdPoints;
  final String? certificateId;

  bool get hasCertificate => certificateId != null;
}
