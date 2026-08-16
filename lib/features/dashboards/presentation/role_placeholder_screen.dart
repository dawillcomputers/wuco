import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_brand.dart';
import '../../../shared/components/wea_components.dart';
import '../../authentication/application/auth_controller.dart';

/// Reserved destination for a role's dashboard.
///
/// Module 04 establishes routing and access control only; the dashboards
/// themselves belong to Module 05 onward.
class RolePlaceholderScreen extends ConsumerWidget {
  const RolePlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: WEAColors.background,
      appBar: AppBar(
        backgroundColor: WEAColors.navy,
        foregroundColor: WEAColors.offWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 84,
        titleSpacing: WEAInsets.lg,
        title: const WEABrandLockup(height: 56, onDark: true, linkToHome: true),
        actions: [
          TextButton(
            onPressed: () => context.go('/profile'),
            style: TextButton.styleFrom(foregroundColor: WEAColors.offWhite),
            child: const Text('PROFILE'),
          ),
          const SizedBox(width: WEAInsets.sm),
          Padding(
            padding: const EdgeInsets.only(right: WEAInsets.lg),
            child: SizedBox(
              height: 36,
              child: WEAOutlinedButton(
                label: 'SIGN OUT',
                compact: true,
                onDark: true,
                onPressed: () => _confirmSignOut(context, ref),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: WEAContainer(
          maxWidth: 720,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null
                      ? 'WEA'
                      : 'SIGNED IN AS ${profile.role.label.toUpperCase()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: WEAInsets.sm),
                Text(title, style: theme.textTheme.displayMedium),
                const SizedBox(height: WEAInsets.md),
                Text(description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: WEAInsets.xl),
                Container(
                  padding: const EdgeInsets.all(WEAInsets.lg),
                  decoration: BoxDecoration(
                    color: WEAColors.surfaceMuted,
                    border: Border.all(color: WEAColors.border),
                    borderRadius: BorderRadius.circular(WEAInsets.radius),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: WEAColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: WEAInsets.sm),
                      Expanded(
                        child: Text(
                          'This area is reserved. Access control is already '
                          'enforced here; the dashboard itself arrives in a '
                          'later module.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WEAInsets.xl),
                Wrap(
                  spacing: WEAInsets.sm,
                  runSpacing: WEAInsets.sm,
                  children: [
                    WEAOutlinedButton(
                      label: 'VIEW PROFILE',
                      onPressed: () => context.go('/profile'),
                    ),
                    WEATextButton(
                      label: 'Back to wuco.academy',
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle confirmation before ending a session, per the module brief.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: WEAColors.card,
      title: const Text('Sign out?'),
      content: const Text(
        'Are you sure you want to sign out of your WEA account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('SIGN OUT'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
