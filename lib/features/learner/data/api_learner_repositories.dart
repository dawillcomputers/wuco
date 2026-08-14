import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/session_store.dart';
import '../../catalogue/domain/catalogue_models.dart' show resolveMediaUrl;
import '../domain/learner_course.dart';
import '../domain/learner_enums.dart';
import '../domain/learner_note.dart';
import '../domain/learner_programme.dart';
import 'learner_repositories.dart';

/// The learner's own study, backed by the API.
///
/// Progress used to live only in the mock store, so nothing survived a refresh
/// and no figure on any dashboard was real. This reads the enrolments, the
/// published structure and the learner's recorded progress, and puts the three
/// together.
///
/// Two things are deliberately not decided here. Whether a lesson is locked
/// comes from the API, which is where the rule is enforced — recomputing it in
/// the client would be a second opinion that could disagree with the one that
/// matters. And whether a video counts as watched is likewise the server's
/// judgement, made against the threshold the lecturer set.
///
/// The catalogue has no separate "course" tier: a programme holds modules,
/// and each module is presented here as a course, which is the shape the
/// learner interface already speaks.
class ApiLearnerRepositories
    implements
        ProgrammeRepository,
        CourseRepository,
        LessonRepository,
        ProgressRepository {
  ApiLearnerRepositories({
    required String baseUrl,
    required SessionStore sessionStore,
    http.Client? client,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _sessions = sessionStore,
       _client = client ?? http.Client();

  final String _baseUrl;
  final SessionStore _sessions;
  final http.Client _client;

  /// One programme's assembled view, kept for the life of a screen so opening
  /// a lesson does not refetch the whole structure.
  final _cache = <String, _ProgrammeView>{};

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await _sessions.read();
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw LearnerFailure(_messageFor(response.statusCode));
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _sessions.read();
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw LearnerFailure(_messageFor(response.statusCode));
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _messageFor(int status) => switch (status) {
    401 => 'Your session has ended. Please sign in again.',
    403 => 'You are not enrolled on this programme.',
    409 => 'Finish the previous lesson before opening this one.',
    404 => 'That is no longer available.',
    _ => 'We could not reach the academy. Please try again.',
  };

  List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in (value as List? ?? const []))
      Map<String, dynamic>.from(row as Map),
  ];

  // --- Assembling a programme ------------------------------------------------

  /// Enrolment, structure and progress, combined.
  Future<_ProgrammeView> _view(String programmeId) async {
    final cached = _cache[programmeId];
    if (cached != null) return cached;

    final detail = await _get('/api/catalogue/programmes/$programmeId');
    final programme = Map<String, dynamic>.from(
      detail['programme'] as Map? ?? const {},
    );
    final id = '${programme['id'] ?? programmeId}';

    // Progress is per lesson and carries the locked decision with it.
    final progress = await _get('/api/learning/programmes/$id');
    final states = {
      for (final row in _rows(progress['lessons'])) '${row['lesson_id']}': row,
    };

    final modules = <CourseModule>[];
    final courses = <LearnerCourse>[];

    for (final module in _rows(detail['modules'])) {
      final moduleId = '${module['id']}';
      final lessons = <Lesson>[
        for (final lesson in _rows(module['lessons']))
          _lesson(lesson, moduleId, moduleId, states['${lesson['id']}']),
      ];
      final courseModule = CourseModule(
        id: moduleId,
        courseId: moduleId,
        number: (module['number'] as num?)?.toInt() ?? modules.length + 1,
        title: '${module['title'] ?? ''}',
        lessons: lessons,
      );
      modules.add(courseModule);

      courses.add(
        LearnerCourse(
          id: moduleId,
          programmeId: id,
          number: courseModule.number,
          title: courseModule.title,
          category: '${programme['area_title'] ?? ''}',
          summary: '${module['summary'] ?? ''}',
          imageUrl:
              resolveMediaUrl(
                imageKey: programme['image_key'] as String?,
                imageUrl: programme['image_url'] as String?,
              ) ??
              '',
          faculty: '',
          durationLabel: '${module['duration_label'] ?? ''}',
          status: _courseStatus(lessons),
          modules: [courseModule],
        ),
      );
    }

    final view = _ProgrammeView(
      programme: LearnerProgramme(
        id: id,
        title: '${programme['title'] ?? ''}',
        category: '${programme['area_title'] ?? ''}',
        summary: '${programme['summary'] ?? ''}',
        imageUrl:
            resolveMediaUrl(
              imageKey: programme['image_key'] as String?,
              imageUrl: programme['image_url'] as String?,
            ) ??
            '',
        durationLabel: '${programme['duration_label'] ?? ''}',
        deliveryMode: '${programme['delivery_mode'] ?? ''}',
        status: _programmeStatus(progress),
        courseIds: [for (final course in courses) course.id],
        cpdPoints: (programme['cpd_points'] as num?)?.toInt() ?? 0,
      ),
      courses: courses,
    );
    _cache[id] = view;
    return view;
  }

  /// A lesson, with the learner's own state on it.
  ///
  /// The state comes from the API rather than being inferred: `locked` in
  /// particular is the server's answer, and the interface's job is to show it,
  /// not to work it out again.
  Lesson _lesson(
    Map<String, dynamic> lesson,
    String moduleId,
    String courseId,
    Map<String, dynamic>? progress,
  ) {
    final locked = progress?['locked'] == true;
    final complete = progress?['complete'] == true;
    final started = '${progress?['state'] ?? ''}' == 'IN_PROGRESS';

    return Lesson(
      id: '${lesson['id']}',
      moduleId: moduleId,
      courseId: courseId,
      title: '${lesson['title'] ?? ''}',
      type: _lessonType('${lesson['lesson_type'] ?? ''}'),
      durationMinutes: (lesson['duration_minutes'] as num?)?.toInt() ?? 0,
      state: locked
          ? LessonState.locked
          : complete
          ? LessonState.completed
          : started
          ? LessonState.inProgress
          : LessonState.available,
      description: '${lesson['summary'] ?? ''}',
      body: lesson['body'] as String?,
      videoUrl: resolveMediaUrl(
        imageKey: lesson['media_key'] as String?,
        imageUrl: lesson['resource_url'] as String?,
      ),
    );
  }

  LessonType _lessonType(String value) => switch (value.toUpperCase()) {
    'TEXT' => LessonType.text,
    'PDF' => LessonType.pdf,
    'PRESENTATION' => LessonType.presentation,
    'AUDIO' => LessonType.audio,
    'EXTERNAL' => LessonType.externalResource,
    'QUIZ' => LessonType.quiz,
    'ASSIGNMENT' => LessonType.assignment,
    'CASE_STUDY' => LessonType.caseStudy,
    'LIVE_SESSION' => LessonType.liveSession,
    _ => LessonType.video,
  };

  CourseStatus _courseStatus(List<Lesson> lessons) {
    if (lessons.isEmpty) return CourseStatus.notStarted;
    if (lessons.every((lesson) => lesson.isComplete)) return CourseStatus.completed;
    if (lessons.any((lesson) => lesson.state != LessonState.available)) {
      return CourseStatus.inProgress;
    }
    return CourseStatus.notStarted;
  }

  ProgrammeStatus _programmeStatus(Map<String, dynamic> progress) {
    final done = (progress['completed_lessons'] as num?)?.toInt() ?? 0;
    final total = (progress['total_lessons'] as num?)?.toInt() ?? 0;
    if (total > 0 && done >= total) return ProgrammeStatus.completed;
    return done == 0 ? ProgrammeStatus.notStarted : ProgrammeStatus.inProgress;
  }

  // --- Programmes -------------------------------------------------------------

  @override
  Future<List<LearnerProgramme>> enrolledProgrammes() async {
    final response = await _get('/api/enrolments');
    final programmes = <LearnerProgramme>[];
    for (final enrolment in _rows(response['enrolments'])) {
      final id = '${enrolment['programme_id']}';
      try {
        programmes.add((await _view(id)).programme);
      } on LearnerFailure {
        // A programme that has since been unpublished should not take the
        // whole list down with it.
        continue;
      }
    }
    return programmes;
  }

  @override
  Future<LearnerProgramme?> programmeById(String id) async {
    try {
      return (await _view(id)).programme;
    } on LearnerFailure {
      return null;
    }
  }

  // --- Courses ----------------------------------------------------------------

  @override
  Future<List<LearnerCourse>> enrolledCourses() async {
    final response = await _get('/api/enrolments');
    final courses = <LearnerCourse>[];
    for (final enrolment in _rows(response['enrolments'])) {
      try {
        courses.addAll((await _view('${enrolment['programme_id']}')).courses);
      } on LearnerFailure {
        continue;
      }
    }
    return courses;
  }

  @override
  Future<List<LearnerCourse>> coursesForProgramme(String programmeId) async {
    try {
      return (await _view(programmeId)).courses;
    } on LearnerFailure {
      return const [];
    }
  }

  @override
  Future<LearnerCourse?> courseById(String id) async {
    for (final view in _cache.values) {
      for (final course in view.courses) {
        if (course.id == id) return course;
      }
    }
    // Not in anything already loaded, so the enrolments are walked once.
    for (final course in await enrolledCourses()) {
      if (course.id == id) return course;
    }
    return null;
  }

  @override
  Future<LearnerCourse?> mostRecentCourse() async {
    final courses = await enrolledCourses();
    for (final course in courses) {
      if (course.status == CourseStatus.inProgress) return course;
    }
    return courses.isEmpty ? null : courses.first;
  }

  // --- Lessons ----------------------------------------------------------------

  @override
  Future<Lesson?> lesson({
    required String courseId,
    required String lessonId,
  }) async {
    // Opening is a request the API may refuse — a locked lesson is refused
    // here, which is the only refusal that means anything.
    await _get('/api/learning/lessons/$lessonId');
    final course = await courseById(courseId);
    for (final lesson in course?.lessons ?? const <Lesson>[]) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }

  @override
  Future<List<Lesson>> bookmarkedLessons() async => const [];

  @override
  Future<List<LessonNote>> notes({
    required String courseId,
    String? lessonId,
  }) async => const [];

  @override
  Future<LessonNote> saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  }) async => throw const LearnerFailure('Notes are not available yet.');

  @override
  Future<void> deleteNote(String noteId) async {}

  // --- Progress ---------------------------------------------------------------

  @override
  Future<LearnerCourse> markLessonComplete({
    required String courseId,
    required String lessonId,
  }) async {
    final result = await _post('/api/learning/lessons/$lessonId/progress', {
      'completed': true,
      'watched_percent': 100,
    });

    // The server may decline to mark it complete — a video with a watch rule
    // is not finished because the client says so.
    if (result['blocked_by_watch_rule'] == true) {
      throw LearnerFailure(
        'Watch at least ${result['min_watch_percent']}% of this lesson before '
        'marking it complete.',
      );
    }

    _cache.clear();
    final course = await courseById(courseId);
    if (course == null) {
      throw const LearnerFailure('That course is no longer available.');
    }
    return course;
  }

  /// How far through a video the learner has got.
  ///
  /// Called as it plays. The server keeps the furthest point reached, so
  /// sending a position behind the recorded one is harmless.
  Future<void> recordWatched({
    required String lessonId,
    required int seconds,
    required int percent,
  }) => _post('/api/learning/lessons/$lessonId/progress', {
    'watched_seconds': seconds,
    'watched_percent': percent,
  });

  @override
  Future<LearnerCourse> setBookmark({
    required String courseId,
    required String lessonId,
    required bool bookmarked,
  }) async {
    final course = await courseById(courseId);
    if (course == null) {
      throw const LearnerFailure('That course is no longer available.');
    }
    // Bookmarks have no backing table yet, so the request is accepted and the
    // course returned unchanged rather than pretending it was saved.
    return course;
  }

  @override
  Future<void> recordCourseAccess(String courseId) async {}
}

/// One programme's structure and the learner's progress through it.
class _ProgrammeView {
  const _ProgrammeView({required this.programme, required this.courses});

  final LearnerProgramme programme;
  final List<LearnerCourse> courses;
}

/// A failure the learner interface can show as it is.
class LearnerFailure implements Exception {
  const LearnerFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
