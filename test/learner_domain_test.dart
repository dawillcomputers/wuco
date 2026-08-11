import 'package:flutter_test/flutter_test.dart';
import 'package:wea_lms/features/authentication/domain/user_profile.dart';
import 'package:wea_lms/features/learner/data/mock/mock_learner_data.dart';
import 'package:wea_lms/features/learner/data/mock/mock_learner_repositories.dart';
import 'package:wea_lms/features/learner/domain/learner_course.dart';
import 'package:wea_lms/features/learner/domain/learner_enums.dart';
import 'package:wea_lms/features/learner/domain/learner_preferences.dart';
import 'package:wea_lms/features/learner/domain/learner_profile.dart';
import 'package:wea_lms/features/learner/domain/learner_records.dart';
import 'package:wea_lms/features/learner/presentation/widgets/lesson_player.dart';

Lesson _lesson(
  String id, {
  LessonState state = LessonState.available,
  int minutes = 10,
}) => Lesson(
  id: id,
  moduleId: 'm1',
  courseId: 'c1',
  title: 'Lesson $id',
  type: LessonType.video,
  durationMinutes: minutes,
  state: state,
);

LearnerCourse _course(List<Lesson> lessons) => LearnerCourse(
  id: 'c1',
  programmeId: 'p1',
  number: 1,
  title: 'Test course',
  category: 'Finance',
  summary: '',
  imageUrl: '',
  faculty: 'Faculty',
  durationLabel: '1h',
  status: CourseStatus.inProgress,
  modules: [
    CourseModule(
      id: 'm1',
      courseId: 'c1',
      number: 1,
      title: 'Module one',
      lessons: lessons,
    ),
  ],
);

void main() {
  group('course progress', () {
    test('is derived from lesson completion, never stored separately', () {
      final course = _course([
        _lesson('a', state: LessonState.completed, minutes: 20),
        _lesson('b', state: LessonState.completed, minutes: 10),
        _lesson('c', minutes: 30),
        _lesson('d', state: LessonState.locked, minutes: 15),
      ]);

      expect(course.totalLessons, 4);
      expect(course.completedLessons, 2);
      expect(course.progressPercent, 50);
      expect(course.remainingMinutes, 45);
    });

    test('resumes at the first incomplete, openable lesson', () {
      final course = _course([
        _lesson('a', state: LessonState.completed),
        _lesson('b', state: LessonState.inProgress),
        _lesson('c'),
      ]);
      expect(course.currentLesson?.id, 'b');
    });

    test('reports no progress for a course with no lessons', () {
      final course = _course(const []);
      expect(course.progressPercent, 0);
      expect(course.currentLesson, isNull);
    });

    test('programme totals aggregate across courses', () {
      final courses = [
        _course([
          _lesson('a', state: LessonState.completed, minutes: 10),
          _lesson('b', minutes: 10),
        ]),
        _course([_lesson('c', state: LessonState.completed, minutes: 10)]),
      ];

      expect(courses.totalLessons, 3);
      expect(courses.totalCompletedLessons, 2);
      expect(courses.combinedProgressPercent, 67);
      expect(courses.totalRemainingMinutes, 10);
    });
  });

  group('course filters', () {
    test('each filter admits only its own status', () {
      expect(CourseFilter.all.matches(CourseStatus.completed), isTrue);
      expect(CourseFilter.inProgress.matches(CourseStatus.inProgress), isTrue);
      expect(CourseFilter.inProgress.matches(CourseStatus.completed), isFalse);
      expect(
        CourseFilter.certificateEligible.matches(
          CourseStatus.certificateEligible,
        ),
        isTrue,
      );
    });
  });

  group('profile completion', () {
    test('counts both account and professional fields', () {
      const account = UserProfile(id: 'u', email: 'a@b.com');
      const learner = LearnerProfile(userId: 'u');
      final completion = ProfileCompletion.of(account, learner);

      expect(completion.total, 10);
      expect(completion.percent, 0);
      expect(completion.isComplete, isFalse);
      expect(completion.missing, contains('Professional title'));
    });

    test('reaches 100% once every field is supplied', () {
      const account = UserProfile(
        id: 'u',
        email: 'a@b.com',
        firstName: 'Ada',
        lastName: 'Obi',
        phone: '+234',
        country: 'Nigeria',
        avatarUrl: 'https://example.com/a.png',
      );
      const learner = LearnerProfile(
        userId: 'u',
        professionalTitle: 'Director',
        organisation: 'CDP',
        bio: 'Executive',
        expertise: ['Trade'],
        linkedInUrl: 'https://linkedin.com/in/ada',
      );

      final completion = ProfileCompletion.of(account, learner);
      expect(completion.percent, 100);
      expect(completion.isComplete, isTrue);
    });
  });

  group('upcoming activities', () {
    test('describe timing plainly rather than urgently', () {
      UpcomingActivity at(Duration offset) => UpcomingActivity(
        id: 'u',
        kind: UpcomingKind.assessment,
        title: 'Assessment',
        context: 'Course',
        dueAt: DateTime.now().add(offset),
      );

      expect(at(const Duration(hours: 2)).relativeLabel, 'Today');
      expect(at(const Duration(days: 1, hours: 2)).relativeLabel, 'Tomorrow');
      expect(at(const Duration(days: 3, hours: 2)).relativeLabel, 'In 3 days');
      expect(at(const Duration(days: -2)).relativeLabel, 'Overdue');
    });
  });

  group('CPD summary', () {
    test('progress is capped and remaining never goes negative', () {
      const summary = CpdSummary(
        year: 2026,
        pointsEarned: 90,
        pointsTarget: 60,
        records: [],
      );
      expect(summary.progress, 1);
      expect(summary.pointsRemaining, 0);
    });
  });

  group('lesson playback', () {
    test('does not count as watched merely because it was opened', () {
      final controller = LessonPlaybackController(
        duration: const Duration(minutes: 10),
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      expect(controller.watchedFraction, 0);
      expect(controller.meetsCompletionCriteria, isFalse);
    });

    test('seeking to the end satisfies the completion criteria', () {
      final controller = LessonPlaybackController(
        duration: const Duration(minutes: 10),
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      controller.seek(const Duration(minutes: 10));
      expect(controller.meetsCompletionCriteria, isTrue);

      // Scrubbing back does not undo what has been watched.
      controller.seek(Duration.zero);
      expect(controller.meetsCompletionCriteria, isTrue);
      expect(controller.position, Duration.zero);
    });

    test('clamps seeks and volume to valid ranges', () {
      final controller = LessonPlaybackController(
        duration: const Duration(minutes: 5),
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);

      controller.skip(const Duration(minutes: -10));
      expect(controller.position, Duration.zero);

      controller.seek(const Duration(minutes: 99));
      expect(controller.position, const Duration(minutes: 5));

      controller.setVolume(3);
      expect(controller.volume, 1);
      controller.toggleMute();
      expect(controller.isMuted, isTrue);
    });
  });

  group('mock repositories', () {
    late MockLearnerStore store;

    setUp(() => store = MockLearnerStore());

    test('completing a lesson advances progress and unlocks the next', () async {
      final repository = MockProgressRepository(store);
      final courses = MockCourseRepository(store);

      final before = (await courses.courseById('course-finance'))!;
      final lesson = before.currentLesson!;
      final lockedAfter = before.lessons[before.lessons.indexOf(lesson) + 1];
      expect(lockedAfter.state, LessonState.locked);

      final after = await repository.markLessonComplete(
        courseId: 'course-finance',
        lessonId: lesson.id,
      );

      expect(after.completedLessons, before.completedLessons + 1);
      expect(
        after.lessons.firstWhere((l) => l.id == lesson.id).state,
        LessonState.completed,
      );
      expect(
        after.lessons.firstWhere((l) => l.id == lockedAfter.id).state,
        LessonState.available,
      );
    });

    test('statistics are derived from the same records the pages show', () async {
      final learner = MockLearnerRepository(store);
      final certificates = await MockCertificateRepository(store).certificates();
      final stats = await learner.stats();

      expect(
        stats.certificatesEarned,
        certificates.where((c) => c.isIssued).length,
      );
      expect(stats.cpdPoints, store.cpd.pointsEarned);
    });

    test('search only returns records the learner already holds', () async {
      final search = MockLearnerSearchRepository(store);

      expect(await search.search(''), isEmpty);
      final hits = await search.search('finance');
      expect(hits, isNotEmpty);
      expect(
        hits.every((hit) => hit.route.startsWith('/learner/')),
        isTrue,
        reason: 'search must not point outside the learner area',
      );

      expect(await search.search('zzzz-no-such-thing'), isEmpty);
    });

    test('notifications can be read individually and in bulk', () async {
      final repository = MockNotificationRepository(store);
      final initial = await repository.notifications();
      final unread = initial.where((n) => !n.read).toList();
      expect(unread, isNotEmpty);

      await repository.markRead(unread.first.id);
      var current = await repository.notifications();
      expect(current.firstWhere((n) => n.id == unread.first.id).read, isTrue);

      await repository.markAllRead();
      current = await repository.notifications();
      expect(current.every((n) => n.read), isTrue);
    });

    test('the CPD target is configurable, the points are not', () async {
      final cpd = MockCpdRepository(store);
      final before = await cpd.summary();

      final after = await cpd.setAnnualTarget(80);
      expect(after.pointsTarget, 80);
      expect(
        after.pointsEarned,
        before.pointsEarned,
        reason: 'changing a goal must not change awarded points',
      );
    });

    test('preferences round-trip and keep the CPD goal in step', () async {
      final preferences = MockPreferencesRepository(store);
      final cpd = MockCpdRepository(store);

      await preferences.save(
        const LearnerPreferences(emailNotifications: false, cpdAnnualTarget: 40),
      );

      final saved = await preferences.preferences();
      expect(saved.emailNotifications, isFalse);
      expect((await cpd.summary()).pointsTarget, 40);
    });

    test('notes can be added, edited and removed', () async {
      final lessons = MockLessonRepository(store);

      final created = await lessons.saveNote(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
        body: 'First thought',
      );
      var notes = await lessons.notes(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
      );
      expect(notes.map((n) => n.id), contains(created.id));

      await lessons.saveNote(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
        body: 'Revised thought',
        noteId: created.id,
      );
      notes = await lessons.notes(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
      );
      expect(notes.firstWhere((n) => n.id == created.id).body, 'Revised thought');

      await lessons.deleteNote(created.id);
      notes = await lessons.notes(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
      );
      expect(notes.map((n) => n.id), isNot(contains(created.id)));
    });

    test('bookmarks are tracked per lesson', () async {
      final progress = MockProgressRepository(store);
      final lessons = MockLessonRepository(store);

      expect(await lessons.bookmarkedLessons(), isEmpty);
      await progress.setBookmark(
        courseId: 'course-finance',
        lessonId: 'les-fin-5',
        bookmarked: true,
      );
      expect(
        (await lessons.bookmarkedLessons()).map((l) => l.id),
        contains('les-fin-5'),
      );
    });

    test('a programme only returns its own courses, in order', () async {
      final courses = MockCourseRepository(store);
      final list = await courses.coursesForProgramme('prog-leadership');

      expect(list, isNotEmpty);
      expect(list.every((c) => c.programmeId == 'prog-leadership'), isTrue);
      expect(
        list.map((c) => c.number).toList(),
        List<int>.from(list.map((c) => c.number))..sort(),
      );
    });
  });
}
