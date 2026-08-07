import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/foundation/presentation/foundation_screen.dart';
import '../features/foundation/presentation/not_found_screen.dart';
import '../features/design_system/presentation/design_system_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/public_site/presentation/public_pages.dart';

GoRouter get appRouter => GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/design-system',
      builder: (context, state) => const DesignSystemScreen(),
    ),
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
      path: '/login',
      builder: (context, state) => const EntryScreen(mode: 'login'),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const EntryScreen(mode: 'register'),
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
    _foundationRoute('/learner', 'Learner Area'),
    _foundationRoute('/lecturer', 'Lecturer Area'),
    _foundationRoute('/admin', 'Administration'),
  ],
);

GoRoute _foundationRoute(String path, String title) => GoRoute(
  path: path,
  builder: (BuildContext context, GoRouterState state) => FoundationScreen(
    title: title,
    description:
        'This section is prepared as part of the WEA application foundation.',
  ),
);
