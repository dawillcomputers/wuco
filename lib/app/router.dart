import 'package:flutter/foundation.dart';
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
import '../features/authentication/presentation/verify_email_screen.dart';
import '../features/dashboards/presentation/role_placeholder_screen.dart';
import '../features/design_system/presentation/design_system_screen.dart';
import '../features/foundation/presentation/not_found_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/public_site/presentation/public_pages.dart';
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
        path: '/verify-email',
        builder: (context, state) => VerifyEmailScreen(
          token: state.uri.queryParameters['token'],
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

      // --- Role destinations ------------------------------------------------
      GoRoute(
        path: '/learner',
        builder: (context, state) => const RolePlaceholderScreen(
          title: 'Learner area',
          description:
              'Your programmes, materials and certificates will appear here.',
        ),
      ),
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
      GoRoute(
        path: '/programmes',
        builder: (context, state) => const ProgrammesScreen(),
      ),
      GoRoute(
        path: '/programmes/:id',
        builder: (context, state) =>
            ProgrammeDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/admissions',
        builder: (context, state) => const AdmissionsScreen(),
      ),
      GoRoute(
        path: '/faculty',
        builder: (context, state) => const FacultyScreen(),
      ),
      GoRoute(path: '/events', builder: (context, state) => const EventsScreen()),
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

/// Decides where a request may go. Kept as a pure function so route protection
/// can be tested without building an application.
@visibleForTesting
String? guardLocation(AuthState auth, String location) =>
    _guard(auth, location);

String? _guard(AuthState auth, String location) {
  // Session not yet resolved: hold on the splash so the login page never
  // flashes for someone who is already signed in.
  if (!auth.isResolved) {
    return location == '/splash' ? null : '/splash';
  }
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

  // Signed in but unverified: only the verification screen and profile are
  // reachable.
  if (auth is AuthEmailUnverified &&
      _isProtected(location) &&
      location != '/verify-email') {
    return '/verify-email';
  }

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
