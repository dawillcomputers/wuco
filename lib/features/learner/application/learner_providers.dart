import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/auth_controller.dart';
import '../../authentication/domain/user_profile.dart';
import '../data/learner_repositories.dart';
import '../data/mock/mock_learner_data.dart';
import '../data/mock/mock_learner_repositories.dart';
import '../domain/learner_course.dart';
import '../domain/learner_enums.dart';
import '../domain/learner_note.dart';
import '../domain/learner_preferences.dart';
import '../domain/learner_profile.dart';
import '../domain/learner_programme.dart';
import '../domain/learner_records.dart';

/// Single in-memory store shared by every mock repository, so completing a
/// lesson in one screen is visible in all the others.
final _storeProvider = Provider<MockLearnerStore>((ref) => MockLearnerStore());

// --- Repositories ---------------------------------------------------------
// Overriding these is the whole swap to a real backend; nothing else changes.

final learnerRepositoryProvider = Provider<LearnerRepository>(
  (ref) => MockLearnerRepository(ref.watch(_storeProvider)),
);
final programmeRepositoryProvider = Provider<ProgrammeRepository>(
  (ref) => MockProgrammeRepository(ref.watch(_storeProvider)),
);
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => MockCourseRepository(ref.watch(_storeProvider)),
);
final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => MockLessonRepository(ref.watch(_storeProvider)),
);
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => MockProgressRepository(ref.watch(_storeProvider)),
);
final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => MockPreferencesRepository(ref.watch(_storeProvider)),
);
final assessmentRepositoryProvider = Provider<AssessmentRepository>(
  (ref) => MockAssessmentRepository(ref.watch(_storeProvider)),
);
final certificateRepositoryProvider = Provider<CertificateRepository>(
  (ref) => MockCertificateRepository(ref.watch(_storeProvider)),
);
final credentialRepositoryProvider = Provider<CredentialRepository>(
  (ref) => MockCredentialRepository(ref.watch(_storeProvider)),
);
final cpdRepositoryProvider = Provider<CpdRepository>(
  (ref) => MockCpdRepository(ref.watch(_storeProvider)),
);
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => MockNotificationRepository(ref.watch(_storeProvider)),
);
final learnerSearchRepositoryProvider = Provider<LearnerSearchRepository>(
  (ref) => MockLearnerSearchRepository(ref.watch(_storeProvider)),
);

// --- Reads ----------------------------------------------------------------

final learnerStatsProvider = FutureProvider<LearnerStats>(
  (ref) => ref.watch(learnerRepositoryProvider).stats(),
);

final recentActivityProvider = FutureProvider<List<LearningActivity>>(
  (ref) => ref.watch(learnerRepositoryProvider).recentActivity(limit: 6),
);

final upcomingActivityProvider = FutureProvider<List<UpcomingActivity>>(
  (ref) => ref.watch(learnerRepositoryProvider).upcoming(limit: 5),
);

final enrolledProgrammesProvider = FutureProvider<List<LearnerProgramme>>(
  (ref) => ref.watch(programmeRepositoryProvider).enrolledProgrammes(),
);

final programmeDetailProvider =
    FutureProvider.family<LearnerProgramme?, String>(
      (ref, id) => ref.watch(programmeRepositoryProvider).programmeById(id),
    );

final enrolledCoursesProvider = FutureProvider<List<LearnerCourse>>(
  (ref) => ref.watch(courseRepositoryProvider).enrolledCourses(),
);

final programmeCoursesProvider =
    FutureProvider.family<List<LearnerCourse>, String>(
      (ref, programmeId) =>
          ref.watch(courseRepositoryProvider).coursesForProgramme(programmeId),
    );

final courseDetailProvider = FutureProvider.family<LearnerCourse?, String>(
  (ref, id) => ref.watch(courseRepositoryProvider).courseById(id),
);

final continueLearningProvider = FutureProvider<LearnerCourse?>(
  (ref) => ref.watch(courseRepositoryProvider).mostRecentCourse(),
);

final assessmentsProvider = FutureProvider<List<Assessment>>(
  (ref) => ref.watch(assessmentRepositoryProvider).assessments(),
);

final resultsProvider = FutureProvider<List<AssessmentResult>>(
  (ref) => ref.watch(assessmentRepositoryProvider).results(),
);

final certificatesProvider = FutureProvider<List<Certificate>>(
  (ref) => ref.watch(certificateRepositoryProvider).certificates(),
);

final credentialsProvider = FutureProvider<List<Credential>>(
  (ref) => ref.watch(credentialRepositoryProvider).credentials(),
);

final cpdSummaryProvider = FutureProvider<CpdSummary>(
  (ref) => ref.watch(cpdRepositoryProvider).summary(),
);

final learnerProfileProvider = FutureProvider<LearnerProfile>(
  (ref) => ref.watch(learnerRepositoryProvider).profile(),
);

/// Completion needs both halves of the account, so it is derived once here
/// rather than recomputed in the profile and dashboard widgets separately.
final profileCompletionProvider = Provider<AsyncValue<ProfileCompletion>>((ref) {
  final account = ref.watch(currentProfileProvider);
  return ref
      .watch(learnerProfileProvider)
      .whenData(
        (learner) => ProfileCompletion.of(
          account ?? const UserProfile(id: '', email: ''),
          learner,
        ),
      );
});

final learnerPreferencesProvider = FutureProvider<LearnerPreferences>(
  (ref) => ref.watch(preferencesRepositoryProvider).preferences(),
);

final bookmarkedLessonsProvider = FutureProvider<List<Lesson>>(
  (ref) => ref.watch(lessonRepositoryProvider).bookmarkedLessons(),
);

/// Notes for one lesson. Keyed by course and lesson so a course-wide list can
/// reuse the same repository call later without a second provider.
final lessonNotesProvider =
    FutureProvider.family<List<LessonNote>, ({String courseId, String lessonId})>(
      (ref, key) => ref
          .watch(lessonRepositoryProvider)
          .notes(courseId: key.courseId, lessonId: key.lessonId),
    );

final notificationsProvider = FutureProvider<List<LearnerNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).notifications(),
);

final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref
      .watch(notificationsProvider)
      .maybeWhen(data: (items) => items.where((n) => !n.read).length, orElse: () => 0),
);

/// Holds one piece of view state. Riverpod 3 removed StateProvider, so simple
/// selections use a small notifier instead.
class ValueNotifierOf<T> extends Notifier<T> {
  ValueNotifierOf(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// Selected filter on the course list.
final courseFilterProvider =
    NotifierProvider<ValueNotifierOf<CourseFilter>, CourseFilter>(
      () => ValueNotifierOf(CourseFilter.all),
    );

/// Free-text query applied on top of [courseFilterProvider].
final courseQueryProvider =
    NotifierProvider<ValueNotifierOf<String>, String>(
      () => ValueNotifierOf(''),
    );

final filteredCoursesProvider = Provider<AsyncValue<List<LearnerCourse>>>((ref) {
  final courses = ref.watch(enrolledCoursesProvider);
  final filter = ref.watch(courseFilterProvider);
  final query = ref.watch(courseQueryProvider).trim().toLowerCase();
  return courses.whenData(
    (list) => [
      for (final course in list)
        if (filter.matches(course.status) &&
            (query.isEmpty ||
                course.title.toLowerCase().contains(query) ||
                course.category.toLowerCase().contains(query) ||
                course.faculty.toLowerCase().contains(query)))
          course,
    ],
  );
});

final searchQueryProvider =
    NotifierProvider<ValueNotifierOf<String>, String>(
      () => ValueNotifierOf(''),
    );

final searchResultsProvider = FutureProvider<List<LearnerSearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(learnerSearchRepositoryProvider).search(query);
});

/// Actions that change learner state, kept out of widgets.
class LearnerActions {
  const LearnerActions(this._ref);
  final Ref _ref;

  Future<void> completeLesson({
    required String courseId,
    required String lessonId,
  }) async {
    await _ref
        .read(progressRepositoryProvider)
        .markLessonComplete(courseId: courseId, lessonId: lessonId);
    _invalidateLearningData();
  }

  Future<void> toggleBookmark({
    required String courseId,
    required String lessonId,
    required bool bookmarked,
  }) async {
    await _ref.read(progressRepositoryProvider).setBookmark(
      courseId: courseId,
      lessonId: lessonId,
      bookmarked: bookmarked,
    );
    _ref
      ..invalidate(courseDetailProvider(courseId))
      ..invalidate(bookmarkedLessonsProvider);
  }

  Future<void> recordAccess(String courseId) =>
      _ref.read(progressRepositoryProvider).recordCourseAccess(courseId);

  Future<void> markNotificationRead(String id) async {
    await _ref.read(notificationRepositoryProvider).markRead(id);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllNotificationsRead() async {
    await _ref.read(notificationRepositoryProvider).markAllRead();
    _ref.invalidate(notificationsProvider);
  }

  Future<void> saveProfile(LearnerProfile profile) async {
    await _ref.read(learnerRepositoryProvider).saveProfile(profile);
    _ref.invalidate(learnerProfileProvider);
  }

  Future<void> saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  }) async {
    await _ref
        .read(lessonRepositoryProvider)
        .saveNote(
          courseId: courseId,
          lessonId: lessonId,
          body: body,
          noteId: noteId,
        );
    _ref.invalidate(lessonNotesProvider((courseId: courseId, lessonId: lessonId)));
  }

  Future<void> deleteNote({
    required String courseId,
    required String lessonId,
    required String noteId,
  }) async {
    await _ref.read(lessonRepositoryProvider).deleteNote(noteId);
    _ref.invalidate(lessonNotesProvider((courseId: courseId, lessonId: lessonId)));
  }

  Future<void> savePreferences(LearnerPreferences preferences) async {
    await _ref.read(preferencesRepositoryProvider).save(preferences);
    _ref
      ..invalidate(learnerPreferencesProvider)
      ..invalidate(cpdSummaryProvider);
  }

  /// The learner's own annual goal — never the points themselves.
  Future<void> setCpdTarget(int points) async {
    await _ref.read(cpdRepositoryProvider).setAnnualTarget(points);
    _ref
      ..invalidate(cpdSummaryProvider)
      ..invalidate(learnerPreferencesProvider);
  }

  /// Completing a lesson moves statistics, activity and course progress at
  /// once, so they are refreshed together.
  void _invalidateLearningData() {
    _ref
      ..invalidate(enrolledCoursesProvider)
      ..invalidate(continueLearningProvider)
      ..invalidate(learnerStatsProvider)
      ..invalidate(recentActivityProvider)
      ..invalidate(courseDetailProvider);
  }
}

final learnerActionsProvider = Provider<LearnerActions>(
  (ref) => LearnerActions(ref),
);
