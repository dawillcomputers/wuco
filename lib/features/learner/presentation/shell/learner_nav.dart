import 'package:flutter/material.dart';

/// One entry in the learner navigation.
class LearnerNavItem {
  const LearnerNavItem({
    required this.label,
    required this.route,
    required this.icon,
    this.badgeCount = 0,
  });

  final String label;
  final String route;
  final IconData icon;
  final int badgeCount;

  /// Matches nested routes so a lesson still highlights "My Courses", while
  /// keeping the dashboard from matching everything under /learner.
  bool isActive(String location) {
    if (route == '/learner') return location == '/learner';
    return location == route || location.startsWith('$route/');
  }
}

/// Grouped so the sidebar reads as sections rather than one long list.
class LearnerNavGroup {
  const LearnerNavGroup({required this.title, required this.items});
  final String title;
  final List<LearnerNavItem> items;
}

abstract final class LearnerNavigation {
  static const learning = LearnerNavGroup(
    title: 'Learning',
    items: [
      LearnerNavItem(
        label: 'Dashboard',
        route: '/learner',
        icon: Icons.space_dashboard_outlined,
      ),
      LearnerNavItem(
        label: 'My Programmes',
        route: '/learner/programmes',
        icon: Icons.workspace_premium_outlined,
      ),
      LearnerNavItem(
        label: 'My Courses',
        route: '/learner/courses',
        icon: Icons.menu_book_outlined,
      ),
    ],
  );

  static const achievement = LearnerNavGroup(
    title: 'Achievement',
    items: [
      LearnerNavItem(
        label: 'Assessments',
        route: '/learner/assessments',
        icon: Icons.assignment_outlined,
      ),
      LearnerNavItem(
        label: 'Results',
        route: '/learner/results',
        icon: Icons.grading_outlined,
      ),
      LearnerNavItem(
        label: 'Certificates',
        route: '/learner/certificates',
        icon: Icons.verified_outlined,
      ),
      LearnerNavItem(
        label: 'Credentials',
        route: '/learner/credentials',
        icon: Icons.badge_outlined,
      ),
      LearnerNavItem(
        label: 'CPD',
        route: '/learner/cpd',
        icon: Icons.trending_up_outlined,
      ),
    ],
  );

  static const community = LearnerNavGroup(
    title: 'Community',
    items: [
      LearnerNavItem(
        label: 'Professional Network',
        route: '/learner/professional-network',
        icon: Icons.groups_outlined,
      ),
      LearnerNavItem(
        label: 'AI Mentor',
        route: '/learner/ai-mentor',
        icon: Icons.auto_awesome_outlined,
      ),
    ],
  );

  static const account = LearnerNavGroup(
    title: 'Account',
    items: [
      LearnerNavItem(
        label: 'Notifications',
        route: '/learner/notifications',
        icon: Icons.notifications_none,
      ),
      LearnerNavItem(
        label: 'Profile',
        route: '/learner/profile',
        icon: Icons.person_outline,
      ),
      LearnerNavItem(
        label: 'Settings',
        route: '/learner/settings',
        icon: Icons.settings_outlined,
      ),
    ],
  );

  static const groups = [learning, achievement, community, account];

  static List<LearnerNavItem> get allItems => [
    for (final group in groups) ...group.items,
  ];

  /// Page title for the current location, used by the mobile header.
  static String titleFor(String location) {
    LearnerNavItem? best;
    for (final item in allItems) {
      if (item.isActive(location)) {
        if (best == null || item.route.length > best.route.length) best = item;
      }
    }
    return best?.label ?? 'Learner';
  }
}
