import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_note.dart';
import '../../domain/learner_preferences.dart';
import '../../domain/learner_profile.dart';
import '../../domain/learner_programme.dart';
import '../../domain/learner_records.dart';
import '../learner_repositories.dart';
import 'mock_learner_data.dart';

/// Small delay so loading and skeleton states are exercised rather than
/// skipped past. Kept short enough not to feel sluggish.
Future<T> _latency<T>(T value) =>
    Future.delayed(const Duration(milliseconds: 220), () => value);

class MockLearnerRepository implements LearnerRepository {
  MockLearnerRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<LearnerStats> stats() {
    final programmes = _store.programmes;
    final courses = _store.courses;
    // Derived from the same records the rest of the dashboard shows, so the
    // headline figures cannot contradict the detail.
    final minutes = courses.fold<int>(
      0,
      (sum, course) => sum + course.lessons
          .where((l) => l.isComplete)
          .fold<int>(0, (m, l) => m + l.durationMinutes),
    );
    return _latency(
      LearnerStats(
        activeProgrammes: programmes
            .where((p) => p.status == ProgrammeStatus.inProgress)
            .length,
        coursesCompleted:
            courses.where((c) => c.status == CourseStatus.completed).length,
        learningMinutes: minutes,
        certificatesEarned:
            _store.certificates.where((c) => c.isIssued).length,
        cpdPoints: _store.cpd.pointsEarned,
        streakDays: 7,
      ),
    );
  }

  @override
  Future<List<LearningActivity>> recentActivity({int limit = 6}) =>
      _latency(_store.activity.take(limit).toList());

  @override
  Future<List<UpcomingActivity>> upcoming({int limit = 5}) {
    final items = [..._store.upcoming]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return _latency(items.take(limit).toList());
  }

  @override
  Future<LearnerProfile> profile() => _latency(_store.profile);

  @override
  Future<LearnerProfile> saveProfile(LearnerProfile profile) =>
      _latency(_store.saveProfile(profile));
}

class MockLessonRepository implements LessonRepository {
  MockLessonRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<Lesson?> lesson({
    required String courseId,
    required String lessonId,
  }) => _latency(_store.lessonById(courseId, lessonId));

  @override
  Future<List<Lesson>> bookmarkedLessons() =>
      _latency(_store.bookmarkedLessons);

  @override
  Future<List<LessonNote>> notes({
    required String courseId,
    String? lessonId,
  }) => _latency([
    for (final note in _store.notes)
      if (note.courseId == courseId &&
          (lessonId == null || note.lessonId == lessonId))
        note,
  ]..sort((a, b) => b.lastTouched.compareTo(a.lastTouched)));

  @override
  Future<LessonNote> saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  }) => _latency(
    _store.saveNote(
      courseId: courseId,
      lessonId: lessonId,
      body: body,
      noteId: noteId,
    ),
  );

  @override
  Future<void> deleteNote(String noteId) async => _store.deleteNote(noteId);
}

class MockProgrammeRepository implements ProgrammeRepository {
  MockProgrammeRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<LearnerProgramme>> enrolledProgrammes() =>
      _latency(_store.programmes);

  @override
  Future<LearnerProgramme?> programmeById(String id) => _latency(
    _store.programmes.where((p) => p.id == id).firstOrNull,
  );
}

class MockCourseRepository implements CourseRepository {
  MockCourseRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<LearnerCourse>> enrolledCourses() => _latency(_store.courses);

  @override
  Future<List<LearnerCourse>> coursesForProgramme(String programmeId) =>
      _latency(
        _store.courses.where((c) => c.programmeId == programmeId).toList()
          ..sort((a, b) => a.number.compareTo(b.number)),
      );

  @override
  Future<LearnerCourse?> courseById(String id) =>
      _latency(_store.courseById(id));

  @override
  Future<LearnerCourse?> mostRecentCourse() {
    final id = _store.mostRecentCourseId;
    return _latency(id == null ? null : _store.courseById(id));
  }
}

class MockProgressRepository implements ProgressRepository {
  MockProgressRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<LearnerCourse> markLessonComplete({
    required String courseId,
    required String lessonId,
  }) => _latency(_store.completeLesson(courseId, lessonId));

  @override
  Future<LearnerCourse> setBookmark({
    required String courseId,
    required String lessonId,
    required bool bookmarked,
  }) => _latency(_store.setBookmark(courseId, lessonId, bookmarked));

  @override
  Future<void> recordCourseAccess(String courseId) async =>
      _store.recordAccess(courseId);
}

class MockAssessmentRepository implements AssessmentRepository {
  MockAssessmentRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<Assessment>> assessments() => _latency(_store.assessments);

  @override
  Future<Assessment?> assessmentById(String id) =>
      _latency(_store.assessments.where((a) => a.id == id).firstOrNull);

  @override
  Future<List<AssessmentResult>> results() => _latency(
    [..._store.results]..sort((a, b) => b.date.compareTo(a.date)),
  );

  @override
  Future<AssessmentResult?> resultById(String id) =>
      _latency(_store.results.where((r) => r.id == id).firstOrNull);
}

class MockCertificateRepository implements CertificateRepository {
  MockCertificateRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<Certificate>> certificates() => _latency(_store.certificates);

  @override
  Future<Certificate?> certificateById(String id) =>
      _latency(_store.certificates.where((c) => c.id == id).firstOrNull);
}

class MockCredentialRepository implements CredentialRepository {
  MockCredentialRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<Credential>> credentials() => _latency(_store.credentials);
}

class MockCpdRepository implements CpdRepository {
  MockCpdRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<CpdSummary> summary() => _latency(_store.cpd);

  @override
  Future<CpdSummary> setAnnualTarget(int points) =>
      _latency(_store.setCpdTarget(points.clamp(1, 500)));
}

class MockPreferencesRepository implements PreferencesRepository {
  MockPreferencesRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<LearnerPreferences> preferences() => _latency(_store.preferences);

  @override
  Future<LearnerPreferences> save(LearnerPreferences preferences) =>
      _latency(_store.savePreferences(preferences));
}

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<LearnerNotification>> notifications() => _latency(
    [..._store.notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> markRead(String id) async => _store.markNotificationRead(id);

  @override
  Future<void> markAllRead() async => _store.markAllNotificationsRead();
}

/// Searches the learner's own records only — it never reaches beyond what the
/// signed-in learner is already entitled to see.
class MockLearnerSearchRepository implements LearnerSearchRepository {
  MockLearnerSearchRepository(this._store);
  final MockLearnerStore _store;

  @override
  Future<List<LearnerSearchResult>> search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return _latency(const <LearnerSearchResult>[]);

    final results = <LearnerSearchResult>[
      for (final programme in _store.programmes)
        if (programme.title.toLowerCase().contains(term) ||
            programme.category.toLowerCase().contains(term))
          LearnerSearchResult(
            title: programme.title,
            subtitle: '${programme.category} · Programme',
            kind: 'Programme',
            route: '/learner/programmes/${programme.id}',
          ),
      for (final course in _store.courses)
        if (course.title.toLowerCase().contains(term) ||
            course.category.toLowerCase().contains(term))
          LearnerSearchResult(
            title: course.title,
            subtitle: '${course.category} · Course',
            kind: 'Course',
            route: '/learner/courses/${course.id}',
          ),
      for (final course in _store.courses)
        for (final lesson in course.lessons)
          if (lesson.title.toLowerCase().contains(term))
            LearnerSearchResult(
              title: lesson.title,
              subtitle: '${course.title} · Lesson',
              kind: 'Lesson',
              route: '/learner/courses/${course.id}/lessons/${lesson.id}',
            ),
      for (final certificate in _store.certificates)
        if (certificate.title.toLowerCase().contains(term))
          LearnerSearchResult(
            title: certificate.title,
            subtitle: 'Certificate',
            kind: 'Certificate',
            route: '/learner/certificates',
          ),
    ];
    return _latency(results.take(12).toList());
  }
}
