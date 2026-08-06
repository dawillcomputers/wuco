import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/foundation/presentation/foundation_screen.dart';
import '../features/foundation/presentation/not_found_screen.dart';
import '../features/home/presentation/home_screen.dart';

GoRouter get appRouter => GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    _foundationRoute('/about', 'About WEA'),
    _foundationRoute('/programmes', 'Executive Programmes'),
    GoRoute(
      path: '/programmes/:id',
      builder: (context, state) => FoundationScreen(
        title: 'Programme',
        description:
            'Programme detail architecture is ready for ${state.pathParameters['id']}.',
      ),
    ),
    _foundationRoute('/admissions', 'Admissions'),
    _foundationRoute('/faculty', 'Faculty'),
    _foundationRoute('/events', 'Events'),
    _foundationRoute('/research', 'Research'),
    _foundationRoute('/contact', 'Contact'),
    _foundationRoute('/login', 'Sign in'),
    _foundationRoute('/register', 'Create an account'),
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
