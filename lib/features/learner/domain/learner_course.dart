import 'learner_enums.dart';

/// A lesson within a course module.
class Lesson {
  const Lesson({
    required this.id,
    required this.moduleId,
    required this.courseId,
    required this.title,
    required this.type,
    required this.durationMinutes,
    this.state = LessonState.locked,
    this.description = '',
    this.objectives = const [],
    this.resources = const [],
    this.bookmarked = false,
    this.videoUrl,
    this.body,
  });

  final String id;
  final String moduleId;
  final String courseId;
  final String title;
  final LessonType type;
  final int durationMinutes;
  final LessonState state;
  final String description;
  final List<String> objectives;
  final List<LessonResource> resources;
  final bool bookmarked;
  final String? videoUrl;
  final String? body;

  bool get isComplete => state == LessonState.completed;

  Lesson copyWith({LessonState? state, bool? bookmarked}) => Lesson(
    id: id,
    moduleId: moduleId,
    courseId: courseId,
    title: title,
    type: type,
    durationMinutes: durationMinutes,
    state: state ?? this.state,
    description: description,
    objectives: objectives,
    resources: resources,
    bookmarked: bookmarked ?? this.bookmarked,
    videoUrl: videoUrl,
    body: body,
  );
}

class LessonResource {
  const LessonResource({
    required this.title,
    required this.kind,
    this.url,
  });

  final String title;
  final String kind;
  final String? url;
}

class CourseModule {
  const CourseModule({
    required this.id,
    required this.courseId,
    required this.number,
    required this.title,
    required this.lessons,
  });

  final String id;
  final String courseId;
  final int number;
  final String title;
  final List<Lesson> lessons;

  int get completedLessons => lessons.where((l) => l.isComplete).length;
  bool get isComplete => lessons.isNotEmpty && completedLessons == lessons.length;
}

/// A course as the learner sees it, including their own progress.
class LearnerCourse {
  const LearnerCourse({
    required this.id,
    required this.programmeId,
    required this.number,
    required this.title,
    required this.category,
    required this.summary,
    required this.imageUrl,
    required this.faculty,
    required this.durationLabel,
    required this.status,
    required this.modules,
    this.objectives = const [],
    this.cpdPoints = 0,
    this.lastAccessed,
  });

  final String id;
  final String programmeId;
  final int number;
  final String title;
  final String category;
  final String summary;
  final String imageUrl;
  final String faculty;
  final String durationLabel;
  final CourseStatus status;
  final List<CourseModule> modules;
  final List<String> objectives;
  final int cpdPoints;
  final DateTime? lastAccessed;

  List<Lesson> get lessons => [for (final m in modules) ...m.lessons];

  int get totalLessons => lessons.length;
  int get completedLessons => lessons.where((l) => l.isComplete).length;

  double get progress =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  int get progressPercent => (progress * 100).round();

  /// Remaining time, derived from the lessons still outstanding rather than
  /// stored, so it cannot drift from actual progress.
  int get remainingMinutes => lessons
      .where((l) => !l.isComplete)
      .fold(0, (sum, l) => sum + l.durationMinutes);

  /// The lesson a learner should resume on: the first not yet completed.
  Lesson? get currentLesson {
    for (final lesson in lessons) {
      if (!lesson.isComplete && lesson.state.isOpenable) return lesson;
    }
    return lessons.isEmpty ? null : lessons.last;
  }

  CourseModule? moduleOf(Lesson lesson) {
    for (final module in modules) {
      if (module.id == lesson.moduleId) return module;
    }
    return null;
  }
}

/// Programme-level figures, derived from the courses it contains.
///
/// Aggregating here rather than storing a separate programme percentage keeps
/// the headline figure honest: it can only ever reflect real lesson progress.
extension LearnerCourseTotals on List<LearnerCourse> {
  int get totalLessons => fold(0, (sum, course) => sum + course.totalLessons);

  int get totalCompletedLessons =>
      fold(0, (sum, course) => sum + course.completedLessons);

  double get combinedProgress =>
      totalLessons == 0 ? 0 : totalCompletedLessons / totalLessons;

  int get combinedProgressPercent => (combinedProgress * 100).round();

  int get totalRemainingMinutes =>
      fold(0, (sum, course) => sum + course.remainingMinutes);

  int get totalCpdPoints => fold(0, (sum, course) => sum + course.cpdPoints);
}
