import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/application/auth_controller.dart';
import '../features/authentication/domain/auth_state.dart';
import '../features/authentication/presentation/auth_loading_screen.dart';
import '../features/authentication/presentation/change_password_screen.dart';
import '../features/authentication/presentation/forgot_password_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/profile_screen.dart';
import '../features/authentication/presentation/register_screen.dart';
import '../features/authentication/presentation/reset_password_screen.dart';
import '../features/dashboards/presentation/role_placeholder_screen.dart';
import '../features/design_system/presentation/design_system_screen.dart';
import '../features/catalogue/presentation/area_screen.dart';
import '../features/catalogue/presentation/catalogue_screen.dart';
import '../features/catalogue/presentation/programme_screen.dart';
import '../features/catalogue/presentation/registration_screen.dart';
import '../features/contact/presentation/contact_screen.dart';
import '../features/events/presentation/event_dashboard_screen.dart';
import '../features/events/presentation/event_detail_screen.dart';
import '../features/events/presentation/event_registration_screen.dart';
import '../features/events/presentation/events_screen.dart';
import '../features/foundation/presentation/not_found_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/learner/presentation/pages/ai_mentor_page.dart';
import '../features/learner/presentation/pages/assessment_detail_page.dart';
import '../features/learner/presentation/pages/assessment_page.dart';
import '../features/learner/presentation/pages/certificate_detail_page.dart';
import '../features/learner/presentation/pages/certificate_page.dart';
import '../features/learner/presentation/pages/course_detail_page.dart';
import '../features/learner/presentation/pages/course_list_page.dart';
import '../features/learner/presentation/pages/cpd_page.dart';
import '../features/learner/presentation/pages/credential_page.dart';
import '../features/learner/presentation/pages/learner_dashboard_page.dart';
import '../features/learner/presentation/pages/learner_profile_page.dart';
import '../features/learner/presentation/pages/learner_settings_page.dart';
import '../features/learner/presentation/pages/learning_page.dart';
import '../features/learner/presentation/pages/notifications_page.dart';
import '../features/learner/presentation/pages/professional_network_page.dart';
import '../features/learner/presentation/pages/programme_detail_page.dart';
import '../features/learner/presentation/pages/programme_list_page.dart';
import '../features/learner/presentation/pages/result_detail_page.dart';
import '../features/learner/presentation/pages/result_page.dart';
import '../features/learner/presentation/shell/learner_shell.dart';
import '../features/public_site/presentation/public_pages.dart';
import '../features/super_admin/presentation/cms/cms_screen.dart';
import '../features/super_admin/presentation/super_admin_console.dart';

/// Routes that require a signed-in account.
const _protectedPrefixes = <String>[
  '/learner',
  '/lecturer',
  '/admin',
  '/super-admin',
  '/application',
  '/professional-network/member',
  '/profile',
  '/change-password',
];

/// Routes only a signed-out visitor should see.
const _guestOnly = <String>{'/login', '/register', '/forgot-password'};

bool _isProtected(String location) =>
    _protectedPrefixes.any((prefix) => location.startsWith(prefix));

/// The application router. Exposed as a provider so route guards can observe
/// authentication without widgets re-implementing the rules.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return _guard(auth, state.matchedLocation);
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const WEAAuthLoadingScreen(),
      ),
      GoRoute(
        path: '/design-system',
        builder: (context, state) => const DesignSystemScreen(),
      ),

      // --- Authentication ---------------------------------------------------
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // --- Learner area -----------------------------------------------------
      // Wrapped in a shell so the sidebar, header and search persist across
      // navigation instead of being rebuilt by each page.
      ShellRoute(
        builder: (context, state, child) => LearnerShell(child: child),
        routes: [
          _learnerRoute('/learner', (state) => const LearnerDashboardPage()),
          GoRoute(
            path: '/learner/dashboard',
            redirect: (context, state) => '/learner',
          ),
          _learnerRoute(
            '/learner/programmes',
            (state) => const ProgrammeListPage(),
          ),
          _learnerRoute(
            '/learner/programmes/:programmeId',
            (state) => ProgrammeDetailPage(
              programmeId: state.pathParameters['programmeId'] ?? '',
            ),
          ),
          _learnerRoute('/learner/courses', (state) => const CourseListPage()),
          _learnerRoute(
            '/learner/courses/:courseId',
            (state) => CourseDetailPage(
              courseId: state.pathParameters['courseId'] ?? '',
            ),
          ),
          _learnerRoute(
            '/learner/assessments',
            (state) => const AssessmentPage(),
          ),
          _learnerRoute(
            '/learner/assessments/:assessmentId',
            (state) => AssessmentDetailPage(
              assessmentId: state.pathParameters['assessmentId'] ?? '',
            ),
          ),
          _learnerRoute('/learner/results', (state) => const ResultPage()),
          _learnerRoute(
            '/learner/results/:resultId',
            (state) => ResultDetailPage(
              resultId: state.pathParameters['resultId'] ?? '',
            ),
          ),
          _learnerRoute(
            '/learner/certificates',
            (state) => const CertificatePage(),
          ),
          _learnerRoute(
            '/learner/certificates/:certificateId',
            (state) => CertificateDetailPage(
              certificateId: state.pathParameters['certificateId'] ?? '',
            ),
          ),
          _learnerRoute(
            '/learner/credentials',
            (state) => const CredentialPage(),
          ),
          _learnerRoute('/learner/cpd', (state) => const CpdPage()),
          _learnerRoute(
            '/learner/notifications',
            (state) => const NotificationsPage(),
          ),
          _learnerRoute(
            '/learner/professional-network',
            (state) => const ProfessionalNetworkPage(),
          ),
          _learnerRoute('/learner/ai-mentor', (state) => const AiMentorPage()),
          _learnerRoute(
            '/learner/profile',
            (state) => const LearnerProfilePage(),
          ),
          _learnerRoute(
            '/learner/settings',
            (state) => const LearnerSettingsPage(),
          ),
        ],
      ),

      // Learning is a focused mode: full width, outside the dashboard shell.
      GoRoute(
        path: '/learner/courses/:courseId/learn',
        builder: (context, state) => LearningPage(
          courseId: state.pathParameters['courseId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/learner/courses/:courseId/lessons/:lessonId',
        builder: (context, state) => LearningPage(
          courseId: state.pathParameters['courseId'] ?? '',
          lessonId: state.pathParameters['lessonId'],
        ),
      ),

      // --- Other role destinations ------------------------------------------
      GoRoute(
        path: '/lecturer',
        builder: (context, state) => const RolePlaceholderScreen(
          title: 'Lecturer area',
          description:
              'Teaching, cohorts and assessment tools will appear here.',
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const RolePlaceholderScreen(
          title: 'Administration',
          description:
              'Programme and learner administration will appear here.',
        ),
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const SuperAdminConsole(),
      ),
      // Catalogue, media, registration and payment administration.
      GoRoute(
        path: '/super-admin/content',
        builder: (context, state) => const CmsScreen(),
      ),
      GoRoute(
        path: '/application',
        builder: (context, state) => const RolePlaceholderScreen(
          title: 'Your application',
          description:
              'Track your admission progress and submitted documents here.',
        ),
      ),
      GoRoute(
        path: '/professional-network/member',
        builder: (context, state) => const RolePlaceholderScreen(
          title: 'Professional Network',
          description:
              'Your member profile, verified records and network access.',
        ),
      ),

      // --- Public website ---------------------------------------------------
      GoRoute(
        path: '/about',
        builder: (context, state) => const EditorialPage(
          eyebrow: 'ABOUT WEA',
          title: 'An academy for leaders shaping Africa’s future.',
          intro:
              'WUCO Executive Academy brings executive education, professional certification and policy capacity development into one focused institutional experience.',
          sections: [
            (
              'Who we are',
              'WEA is Africa’s Executive Academy for Leadership, Trade, Investment and Professional Development.',
            ),
            (
              'Our mission',
              'To strengthen the judgement, capability and professional impact of leaders working across Africa and the global economy.',
            ),
            (
              'Our vision',
              'A future in which African leaders and institutions have the learning, networks and confidence to shape enduring progress.',
            ),
            (
              'Our approach',
              'Rigorous executive learning connects academic discipline, professional practice and regional relevance.',
            ),
            (
              'Institutional backing',
              'WEA is backed by the World United Consumer Organisation.',
            ),
            (
              'Executive education philosophy',
              'We focus on practical decisions, constructive challenge and learning that remains relevant beyond a single programme.',
            ),
          ],
          ctaLabel: 'EXPLORE PROGRAMMES',
          ctaPath: '/programmes',
        ),
      ),
      // The catalogue is served from the API, so these pages reflect whatever
      // a Super Admin has published without a release.
      GoRoute(
        path: '/programmes',
        builder: (context, state) => const CatalogueScreen(),
      ),
      GoRoute(
        path: '/programmes/area/:slug',
        builder: (context, state) =>
            AreaScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/programmes/:slug',
        builder: (context, state) =>
            ProgrammeScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/register/:slug',
        builder: (context, state) =>
            RegistrationScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/admissions',
        builder: (context, state) => const AdmissionsScreen(),
      ),
      GoRoute(
        path: '/faculty',
        builder: (context, state) => const FacultyScreen(),
      ),
      // Events are content, not code: the calendar, each event page and its
      // registration all come from rows a Super Admin published.
      GoRoute(path: '/events', builder: (context, state) => const EventsScreen()),
      GoRoute(
        path: '/events/registration/:reference',
        builder: (context, state) => EventDashboardScreen(
          reference: state.pathParameters['reference'] ?? '',
        ),
      ),
      GoRoute(
        path: '/events/:slug',
        builder: (context, state) =>
            EventDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/events/:slug/register',
        builder: (context, state) =>
            EventRegistrationScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/research',
        builder: (context, state) => const ResearchScreen(),
      ),
      GoRoute(
        path: '/professional-network',
        builder: (context, state) => const NetworkScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/apply',
        builder: (context, state) => const EntryScreen(mode: 'apply'),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PolicyScreen(terms: false),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const PolicyScreen(terms: true),
      ),
    ],
  );
});

/// A learner page with the area's shared transition.
///
/// A short crossfade rather than a slide: within a dashboard shell only the
/// content pane changes, and lateral motion there reads as a glitch.
GoRoute _learnerRoute(String path, Widget Function(GoRouterState) build) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: build(state),
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
      ),
    );

/// Decides where a request may go. Kept as a pure function so route protection
/// can be tested without building an application.
@visibleForTesting
String? guardLocation(AuthState auth, String location) =>
    _guard(auth, location);

String? _guard(AuthState auth, String location) {
  // Session not yet inspected: hold on the splash so the login page never
  // flashes for someone who is already signed in.
  if (auth is AuthInitial) {
    return location == '/splash' ? null : '/splash';
  }

  // A transient operation — signing in, saving a profile, changing a password
  // — must leave the learner where they are. Treating it like an unresolved
  // session would bounce them through the splash and back to their landing
  // route mid-edit.
  if (auth is AuthLoading) return null;
  if (location == '/splash') {
    final profile = auth.profile;
    return auth.isAuthenticated && profile != null
        ? profile.role.landingRoute
        : '/';
  }

  final profile = auth.profile;
  final signedIn = auth.isAuthenticated && profile != null;

  // A temporary password gets one destination until it is replaced.
  if (profile != null &&
      profile.mustChangePassword &&
      location != '/change-password') {
    return '/change-password';
  }

  // Email verification no longer gates access. Accounts are created active,
  // because holding a new registrant behind a link in an inbox cost more
  // registrations than the check was worth. /verify-email still exists for
  // anyone following an older link; it simply is not a wall any more.

  if (signedIn && _guestOnly.contains(location)) {
    return profile.role.landingRoute;
  }

  if (_isProtected(location)) {
    if (!signedIn) return '/login';
    // Role protection is enforced here as well as in the API; a learner
    // typing /admin lands back in their own area.
    if (!profile.role.canAccess(location)) {
      return profile.role.landingRoute;
    }
  }

  return null;
}
