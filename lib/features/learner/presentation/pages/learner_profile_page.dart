import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../authentication/domain/user_profile.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_profile.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';
import '../widgets/profile_edit_form.dart';

/// The learner's professional profile.
///
/// Identity lives on the account (authentication owns it); the professional
/// detail lives on [LearnerProfile]. Both are shown here as one record.
class LearnerProfilePage extends ConsumerStatefulWidget {
  const LearnerProfilePage({super.key});

  @override
  ConsumerState<LearnerProfilePage> createState() => _LearnerProfilePageState();
}

class _LearnerProfilePageState extends ConsumerState<LearnerProfilePage> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentProfileProvider);
    final learner = ref.watch(learnerProfileProvider);
    final completion = ref.watch(profileCompletionProvider).value;

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LearnerPageHeader(
            eyebrow: 'Profile',
            title: 'Your professional profile',
            description:
                'How you are represented across WEA and, when you choose it, '
                'the Professional Network.',
            trailing: _editing
                ? null
                : OutlinedButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('EDIT PROFILE'),
                  ),
          ),
          LearnerAsync(
            value: learner,
            onRetry: () => ref.invalidate(learnerProfileProvider),
            loading: const LearnerCardSkeleton(count: 2, height: 200),
            data: (profile) => account == null
                ? const LearnerErrorState(
                    message:
                        'We could not load your account. Please sign in again.',
                  )
                : _editing
                ? ProfileEditForm(
                    account: account,
                    learner: profile,
                    onDone: () => setState(() => _editing = false),
                  )
                : _ProfileView(
                    account: account,
                    learner: profile,
                    completion: completion,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.account,
    required this.learner,
    required this.completion,
  });

  final UserProfile account;
  final LearnerProfile learner;
  final ProfileCompletion? completion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: WEAColors.accent,
                foregroundColor: Colors.white,
                backgroundImage: account.avatarUrl == null
                    ? null
                    : NetworkImage(account.avatarUrl!),
                child: account.avatarUrl != null
                    ? null
                    : Text(
                        account.initials,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: WEAInsets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.fullName, style: theme.textTheme.headlineSmall),
                    if (learner.professionalTitle.isNotEmpty)
                      Text(
                        learner.organisation.isEmpty
                            ? learner.professionalTitle
                            : '${learner.professionalTitle}, '
                                  '${learner.organisation}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    const SizedBox(height: WEAInsets.xs),
                    Wrap(
                      spacing: WEAInsets.xs,
                      runSpacing: WEAInsets.xs,
                      children: [
                        LearnerStatusChip(
                          label: account.role.label,
                          tone: WEAColors.accent,
                          icon: Icons.school_outlined,
                        ),
                        LearnerStatusChip(
                          label: account.emailVerified
                              ? 'Email verified'
                              : 'Email unverified',
                          tone: account.emailVerified
                              ? WEAColors.success
                              : WEAColors.warning,
                          icon: account.emailVerified
                              ? Icons.mark_email_read_outlined
                              : Icons.mark_email_unread_outlined,
                        ),
                        LearnerStatusChip(
                          label: learner.visibility.label,
                          tone: WEAColors.mutedText,
                          icon: Icons.visibility_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (completion != null && !completion!.isComplete) ...[
          const SizedBox(height: WEAInsets.md),
          LearnerCard(
            padding: const EdgeInsets.all(WEAInsets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile ${completion!.percent}% complete',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: WEAInsets.xs),
                LearnerProgressBar(value: completion!.fraction),
                const SizedBox(height: WEAInsets.xs),
                Text(
                  'Still to add: ${completion!.missing.join(', ')}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'About',
          child: Text(
            learner.bio.isEmpty
                ? 'Add a short professional biography so faculty and fellow '
                      'executives understand your context.'
                : learner.bio,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Contact details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerFactGrid(
                minWidth: 200,
                facts: [
                  LearnerFact(
                    label: 'Email',
                    value: account.email,
                    icon: Icons.mail_outline,
                  ),
                  LearnerFact(
                    label: 'Phone',
                    value: account.phone?.trim().isNotEmpty ?? false
                        ? account.phone!
                        : 'Not provided',
                    icon: Icons.phone_outlined,
                  ),
                  LearnerFact(
                    label: 'Country',
                    value: account.country?.trim().isNotEmpty ?? false
                        ? account.country!
                        : 'Not provided',
                    icon: Icons.public_outlined,
                  ),
                  LearnerFact(
                    label: 'City',
                    value: learner.city?.trim().isNotEmpty ?? false
                        ? learner.city!
                        : 'Not provided',
                    icon: Icons.location_city_outlined,
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              const LearnerLockedNote(
                message:
                    'Your email and phone number are never shared publicly. '
                    'Only the details you choose are visible to others.',
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Areas of expertise',
          child: learner.expertise.isEmpty
              ? Text(
                  'Add the areas you work in so WEA can suggest relevant '
                  'programmes and connections.',
                  style: theme.textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: WEAInsets.xs,
                  runSpacing: WEAInsets.xs,
                  children: [
                    for (final area in learner.expertise)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: WEAColors.surfaceMuted,
                          border: Border.all(color: WEAColors.border),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(area, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Professional links',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LinkRow(
                icon: Icons.link,
                label: 'LinkedIn',
                value: learner.linkedInUrl,
              ),
              _LinkRow(
                icon: Icons.language_outlined,
                label: 'Website',
                value: learner.websiteUrl,
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Account security',
          child: Wrap(
            spacing: WEAInsets.sm,
            runSpacing: WEAInsets.xs,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/change-password'),
                child: const Text('CHANGE PASSWORD'),
              ),
              TextButton(
                onPressed: () => context.go('/learner/settings'),
                child: const Text('PRIVACY & SETTINGS'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provided = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.xs),
      child: Row(
        children: [
          Icon(icon, size: 17, color: WEAColors.mutedText),
          const SizedBox(width: WEAInsets.xs),
          SizedBox(width: 90, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(
            child: Text(
              provided ? value! : 'Not provided',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: provided ? WEAColors.accent : WEAColors.mutedText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
