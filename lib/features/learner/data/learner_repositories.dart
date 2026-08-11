import '../domain/learner_course.dart';
import '../domain/learner_note.dart';
import '../domain/learner_preferences.dart';
import '../domain/learner_profile.dart';
import '../domain/learner_programme.dart';
import '../domain/learner_records.dart';

/// Contracts for every piece of learner data.
///
/// Presentation code depends only on these, so the mock implementations can be
/// swapped for Worker-backed ones without touching a widget. Each method is
/// scoped to the signed-in learner; none accepts another learner's id.
abstract interface class LearnerRepository {
  Future<LearnerStats> stats();
  Future<List<LearningActivity>> recentActivity({int limit});
  Future<List<UpcomingActivity>> upcoming({int limit});

  /// The professional half of the learner's own profile.
  Future<LearnerProfile> profile();
  Future<LearnerProfile> saveProfile(LearnerProfile profile);
}

abstract interface class ProgrammeRepository {
  Future<List<LearnerProgramme>> enrolledProgrammes();
  Future<LearnerProgramme?> programmeById(String id);
}

abstract interface class CourseRepository {
  Future<List<LearnerCourse>> enrolledCourses();
  Future<List<LearnerCourse>> coursesForProgramme(String programmeId);
  Future<LearnerCourse?> courseById(String id);

  /// The course the learner last opened, for Continue Learning.
  Future<LearnerCourse?> mostRecentCourse();
}

/// Lesson-level reads plus the learner's own notes.
///
/// Notes are the only lesson data a learner may write; lesson state itself is
/// changed through [ProgressRepository], which the backend authorises.
abstract interface class LessonRepository {
  Future<Lesson?> lesson({required String courseId, required String lessonId});

  Future<List<Lesson>> bookmarkedLessons();

  Future<List<LessonNote>> notes({required String courseId, String? lessonId});

  Future<LessonNote> saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  });

  Future<void> deleteNote(String noteId);
}

abstract interface class ProgressRepository {
  /// Records completion. Progress is derived from lesson state rather than
  /// stored separately, so the two cannot disagree.
  Future<LearnerCourse> markLessonComplete({
    required String courseId,
    required String lessonId,
  });

  Future<LearnerCourse> setBookmark({
    required String courseId,
    required String lessonId,
    required bool bookmarked,
  });

  Future<void> recordCourseAccess(String courseId);
}

abstract interface class AssessmentRepository {
  Future<List<Assessment>> assessments();
  Future<Assessment?> assessmentById(String id);
  Future<List<AssessmentResult>> results();
  Future<AssessmentResult?> resultById(String id);
}

abstract interface class CertificateRepository {
  Future<List<Certificate>> certificates();
  Future<Certificate?> certificateById(String id);
}

abstract interface class CredentialRepository {
  Future<List<Credential>> credentials();
}

abstract interface class CpdRepository {
  Future<CpdSummary> summary();

  /// Sets the learner's personal annual goal. Points earned are never writable
  /// from the client — only the target the learner is aiming at.
  Future<CpdSummary> setAnnualTarget(int points);
}

abstract interface class PreferencesRepository {
  Future<LearnerPreferences> preferences();
  Future<LearnerPreferences> save(LearnerPreferences preferences);
}

abstract interface class NotificationRepository {
  Future<List<LearnerNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

abstract interface class LearnerSearchRepository {
  Future<List<LearnerSearchResult>> search(String query);
}
