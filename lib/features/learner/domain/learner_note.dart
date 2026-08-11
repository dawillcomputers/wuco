/// A learner's private note against a lesson.
///
/// Notes belong to the learner alone; nothing here is shared with faculty or
/// other learners.
class LessonNote {
  const LessonNote({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.body,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String lessonId;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DateTime get lastTouched => updatedAt ?? createdAt;

  LessonNote copyWith({String? body, DateTime? updatedAt}) => LessonNote(
    id: id,
    courseId: courseId,
    lessonId: lessonId,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
