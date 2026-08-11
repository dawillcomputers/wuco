import 'package:wea_lms/features/learner/data/learner_repositories.dart';
import 'package:wea_lms/features/learner/domain/learner_course.dart';
import 'package:wea_lms/features/learner/domain/learner_note.dart';
import 'package:wea_lms/features/learner/domain/learner_preferences.dart';
import 'package:wea_lms/features/learner/domain/learner_profile.dart';
import 'package:wea_lms/features/learner/domain/learner_programme.dart';
import 'package:wea_lms/features/learner/domain/learner_records.dart';

/// Which shape of backend a learner test should run against.
enum LearnerDataMode {
  /// The seeded mock backend — the default.
  seeded,

  /// Every collection empty, for exercising empty states.
  empty,

  /// Every call fails, for exercising error states and retry.
  failing,
}

/// Raised by the failing stubs. Learner screens must never show this text.
class StubFailure implements Exception {
  const StubFailure();
  @override
  String toString() => 'StubFailure: the backend is unreachable';
}

/// Shared behaviour: return the empty value, or fail, depending on the mode.
mixin _Stub {
  bool get fail;

  Future<T> value<T>(T value) =>
      fail ? Future<T>.error(const StubFailure()) : Future<T>.value(value);
}

class StubLearnerRepository with _Stub implements LearnerRepository {
  StubLearnerRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<LearnerStats> stats() => value(
    const LearnerStats(
      activeProgrammes: 0,
      coursesCompleted: 0,
      learningMinutes: 0,
      certificatesEarned: 0,
      cpdPoints: 0,
    ),
  );

  @override
  Future<List<LearningActivity>> recentActivity({int limit = 6}) =>
      value(const []);

  @override
  Future<List<UpcomingActivity>> upcoming({int limit = 5}) => value(const []);

  @override
  Future<LearnerProfile> profile() =>
      value(const LearnerProfile(userId: 'user-1'));

  @override
  Future<LearnerProfile> saveProfile(LearnerProfile profile) => value(profile);
}

class StubProgrammeRepository with _Stub implements ProgrammeRepository {
  StubProgrammeRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<LearnerProgramme>> enrolledProgrammes() => value(const []);

  @override
  Future<LearnerProgramme?> programmeById(String id) => value(null);
}

class StubCourseRepository with _Stub implements CourseRepository {
  StubCourseRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<LearnerCourse>> enrolledCourses() => value(const []);

  @override
  Future<List<LearnerCourse>> coursesForProgramme(String programmeId) =>
      value(const []);

  @override
  Future<LearnerCourse?> courseById(String id) => value(null);

  @override
  Future<LearnerCourse?> mostRecentCourse() => value(null);
}

class StubLessonRepository with _Stub implements LessonRepository {
  StubLessonRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<Lesson?> lesson({required String courseId, required String lessonId}) =>
      value(null);

  @override
  Future<List<Lesson>> bookmarkedLessons() => value(const []);

  @override
  Future<List<LessonNote>> notes({
    required String courseId,
    String? lessonId,
  }) => value(const []);

  @override
  Future<LessonNote> saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  }) => value(
    LessonNote(
      id: 'stub',
      courseId: courseId,
      lessonId: lessonId,
      body: body,
      createdAt: DateTime(2026),
    ),
  );

  @override
  Future<void> deleteNote(String noteId) => value(null);
}

class StubAssessmentRepository with _Stub implements AssessmentRepository {
  StubAssessmentRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<Assessment>> assessments() => value(const []);

  @override
  Future<Assessment?> assessmentById(String id) => value(null);

  @override
  Future<List<AssessmentResult>> results() => value(const []);

  @override
  Future<AssessmentResult?> resultById(String id) => value(null);
}

class StubCertificateRepository with _Stub implements CertificateRepository {
  StubCertificateRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<Certificate>> certificates() => value(const []);

  @override
  Future<Certificate?> certificateById(String id) => value(null);
}

class StubCredentialRepository with _Stub implements CredentialRepository {
  StubCredentialRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<Credential>> credentials() => value(const []);
}

class StubCpdRepository with _Stub implements CpdRepository {
  StubCpdRepository({required this.fail});
  @override
  final bool fail;

  CpdSummary get _empty =>
      CpdSummary(year: 2026, pointsEarned: 0, pointsTarget: 60, records: const []);

  @override
  Future<CpdSummary> summary() => value(_empty);

  @override
  Future<CpdSummary> setAnnualTarget(int points) => value(_empty);
}

class StubNotificationRepository with _Stub implements NotificationRepository {
  StubNotificationRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<LearnerNotification>> notifications() => value(const []);

  @override
  Future<void> markRead(String id) => value(null);

  @override
  Future<void> markAllRead() => value(null);
}

class StubPreferencesRepository with _Stub implements PreferencesRepository {
  StubPreferencesRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<LearnerPreferences> preferences() =>
      value(const LearnerPreferences());

  @override
  Future<LearnerPreferences> save(LearnerPreferences preferences) =>
      value(preferences);
}

class StubSearchRepository with _Stub implements LearnerSearchRepository {
  StubSearchRepository({required this.fail});
  @override
  final bool fail;

  @override
  Future<List<LearnerSearchResult>> search(String query) => value(const []);
}
