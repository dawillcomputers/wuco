import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_preferences.dart';
import '../../domain/learner_profile.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Account, notification, privacy, security, learning and accessibility
/// settings, all persisted through the preferences repository.
class LearnerSettingsPage extends ConsumerWidget {
  const LearnerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LearnerPageHeader(
          eyebrow: 'Settings',
          title: 'Your settings',
          description:
              'Control how WEA contacts you, what others can see, and how the '
              'learning experience behaves.',
        ),
        LearnerAsync(
          value: ref.watch(learnerPreferencesProvider),
          onRetry: () => ref.invalidate(learnerPreferencesProvider),
          loading: const LearnerCardSkeleton(count: 3, height: 150),
          data: (preferences) => _SettingsSections(preferences: preferences),
        ),
      ],
    ),
  );
}

class _SettingsSections extends ConsumerWidget {
  const _SettingsSections({required this.preferences});

  final LearnerPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentProfileProvider);

    void save(LearnerPreferences next) =>
        ref.read(learnerActionsProvider).savePreferences(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPanel(
          title: 'Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerFactGrid(
                minWidth: 200,
                facts: [
                  LearnerFact(
                    label: 'Signed in as',
                    value: account?.email ?? '—',
                    icon: Icons.mail_outline,
                  ),
                  LearnerFact(
                    label: 'Role',
                    value: account?.role.label ?? '—',
                    icon: Icons.badge_outlined,
                  ),
                  LearnerFact(
                    label: 'Account status',
                    value: account?.status.label ?? '—',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              Wrap(
                spacing: WEAInsets.sm,
                runSpacing: WEAInsets.xs,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/learner/profile'),
                    child: const Text('EDIT PROFILE'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/change-password'),
                    child: const Text('CHANGE PASSWORD'),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.sm),
              const LearnerLockedNote(
                message:
                    'Your role and account status are set by WEA and cannot be '
                    'changed from here.',
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Notifications',
          child: Column(
            children: [
              _SettingSwitch(
                title: 'Email notifications',
                subtitle: 'Receive WEA updates by email as well as in-app.',
                value: preferences.emailNotifications,
                onChanged: (value) =>
                    save(preferences.copyWith(emailNotifications: value)),
              ),
              _SettingSwitch(
                title: 'Assessment reminders',
                subtitle: 'A reminder before an assessment closes.',
                value: preferences.assessmentReminders,
                onChanged: (value) =>
                    save(preferences.copyWith(assessmentReminders: value)),
              ),
              _SettingSwitch(
                title: 'Result alerts',
                subtitle: 'Tell me when a result is published.',
                value: preferences.resultAlerts,
                onChanged: (value) =>
                    save(preferences.copyWith(resultAlerts: value)),
              ),
              _SettingSwitch(
                title: 'Programme announcements',
                subtitle: 'News from the programmes you are enrolled on.',
                value: preferences.programmeAnnouncements,
                onChanged: (value) =>
                    save(preferences.copyWith(programmeAnnouncements: value)),
              ),
              _SettingSwitch(
                title: 'Professional Network updates',
                subtitle: 'Announcements about the network as it opens.',
                value: preferences.networkUpdates,
                onChanged: (value) =>
                    save(preferences.copyWith(networkUpdates: value)),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Privacy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ProfileVisibility>(
                initialValue: preferences.visibility,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Profile visibility',
                ),
                items: [
                  for (final option in ProfileVisibility.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text('${option.label} — ${option.description}'),
                    ),
                ],
                onChanged: (value) => value == null
                    ? null
                    : save(preferences.copyWith(visibility: value)),
              ),
              const SizedBox(height: WEAInsets.sm),
              _SettingSwitch(
                title: 'Show credentials on my profile',
                subtitle:
                    'Display verified certificates and badges to those who '
                    'can see your profile.',
                value: preferences.showCredentialsPublicly,
                onChanged: (value) => save(
                  preferences.copyWith(showCredentialsPublicly: value),
                ),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Learning preferences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingSwitch(
                title: 'Play the next lesson automatically',
                subtitle:
                    'Move straight on when a lesson finishes. Completion is '
                    'still recorded only when you mark it.',
                value: preferences.autoplayNextLesson,
                onChanged: (value) =>
                    save(preferences.copyWith(autoplayNextLesson: value)),
              ),
              _SettingSwitch(
                title: 'Captions on by default',
                subtitle: 'Show captions whenever a lesson supports them.',
                value: preferences.captionsByDefault,
                onChanged: (value) =>
                    save(preferences.copyWith(captionsByDefault: value)),
                last: true,
              ),
              const SizedBox(height: WEAInsets.md),
              DropdownButtonFormField<double>(
                initialValue: preferences.playbackSpeed,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Default playback speed',
                ),
                items: [
                  for (final speed in LearnerPreferences.playbackSpeeds)
                    DropdownMenuItem(value: speed, child: Text('${speed}x')),
                ],
                onChanged: (value) => value == null
                    ? null
                    : save(preferences.copyWith(playbackSpeed: value)),
              ),
              const SizedBox(height: WEAInsets.md),
              DropdownButtonFormField<int>(
                initialValue: preferences.cpdAnnualTarget,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Annual CPD goal',
                  helperText:
                      'Set this to match your professional body’s requirement.',
                ),
                items: [
                  for (final target in {20, 30, 40, 60, 80, 100,
                    preferences.cpdAnnualTarget}.toList()..sort())
                    DropdownMenuItem(
                      value: target,
                      child: Text('$target points'),
                    ),
                ],
                onChanged: (value) => value == null
                    ? null
                    : ref.read(learnerActionsProvider).setCpdTarget(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Accessibility',
          child: Column(
            children: [
              _SettingSwitch(
                title: 'Reduce motion',
                subtitle:
                    'Minimise animation and transitions across the learner '
                    'area.',
                value: preferences.reducedMotion,
                onChanged: (value) =>
                    save(preferences.copyWith(reducedMotion: value)),
              ),
              _SettingSwitch(
                title: 'Larger text',
                subtitle: 'Increase the base text size for reading comfort.',
                value: preferences.largerText,
                onChanged: (value) =>
                    save(preferences.copyWith(largerText: value)),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Security',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signing out clears your session on this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: WEAInsets.md),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context, ref),
                icon: const Icon(Icons.logout_outlined, size: 18),
                label: const Text('SIGN OUT'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: WEAColors.border)),
    ),
    child: SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
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
