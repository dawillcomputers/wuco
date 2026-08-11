import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_profile.dart';
import '../../domain/learner_records.dart';
import 'learner_progress.dart';
import 'learner_states.dart';

/// Dashboard hero. Greets the learner by name and sets the tone for the day
/// without resorting to motivational filler.
class LearnerWelcomeBanner extends StatelessWidget {
  const LearnerWelcomeBanner({
    super.key,
    required this.firstName,
    required this.streakDays,
    this.now,
  });

  final String firstName;
  final int streakDays;

  /// Injectable so the greeting is testable rather than clock-dependent.
  final DateTime? now;

  static String greetingFor(DateTime moment) => switch (moment.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = greetingFor(now ?? DateTime.now());
    final name = firstName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.navy,
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WUCO EXECUTIVE ACADEMY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.accentSoft,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(
            name.isEmpty ? '$greeting.' : '$greeting, $name.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: WEAColors.offWhite,
            ),
          ),
          const SizedBox(height: WEAInsets.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Continue your journey with WUCO Executive Academy. Your next '
              'breakthrough may begin with the next lesson.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: WEAColors.offWhite.withValues(alpha: .82),
              ),
            ),
          ),
          if (streakDays > 1) ...[
            const SizedBox(height: WEAInsets.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: WEAInsets.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: WEAColors.offWhite.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_outlined,
                    size: 15,
                    color: WEAColors.accentSoft,
                  ),
                  const SizedBox(width: 6),
                  // Flexible so the pill shrinks on a narrow phone, or when
                  // the learner has scaled their text up, rather than
                  // overflowing the banner.
                  Flexible(
                    child: Text(
                      '$streakDays-day learning streak',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: WEAColors.offWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The five headline figures. Wraps rather than scrolls so nothing is hidden
/// on a narrow screen.
class LearnerStatRow extends StatelessWidget {
  const LearnerStatRow({super.key, required this.stats});

  final LearnerStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      LearnerStatCard(
        value: stats.activeProgrammes.toString().padLeft(2, '0'),
        label: 'Active programmes',
        icon: Icons.workspace_premium_outlined,
      ),
      LearnerStatCard(
        value: stats.coursesCompleted.toString().padLeft(2, '0'),
        label: 'Courses completed',
        icon: Icons.menu_book_outlined,
      ),
      LearnerStatCard(
        value: stats.learningHoursLabel,
        label: 'Learning hours',
        icon: Icons.schedule,
      ),
      LearnerStatCard(
        value: stats.certificatesEarned.toString().padLeft(2, '0'),
        label: 'Certificates earned',
        icon: Icons.verified_outlined,
      ),
      LearnerStatCard(
        value: stats.cpdPoints.toString(),
        label: 'CPD points',
        icon: Icons.trending_up_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = WEAInsets.sm;
        final columns = switch (constraints.maxWidth) {
          < 420 => 2,
          < 760 => 3,
          < 1040 => 3,
          _ => 5,
        };
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

/// Prompt to finish the profile. Shown only while something is outstanding,
/// and phrased as an invitation rather than a warning.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.completion});

  final ProfileCompletion completion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      padding: const EdgeInsets.all(WEAInsets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile ${completion.percent}% complete',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/learner/profile'),
                child: const Text('COMPLETE'),
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          LearnerProgressBar(value: completion.fraction),
          const SizedBox(height: WEAInsets.xs),
          Text(
            completion.missing.length == 1
                ? 'Add your ${completion.missing.first.toLowerCase()} to get '
                      'the most from WEA.'
                : 'Still to add: ${completion.missing.take(3).join(', ')}.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Entry point to a capability that arrives in a later module.
///
/// Presented as a genuine part of the academy rather than a disabled stub: the
/// destination exists and explains itself, so nothing feels broken.
class FeatureEntryCard extends StatefulWidget {
  const FeatureEntryCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.route,
    required this.icon,
    this.onDark = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final String route;
  final IconData icon;

  /// Navy treatment, used for the AI Mentor so it reads as the flagship of the
  /// two without introducing a new colour.
  final bool onDark;

  @override
  State<FeatureEntryCard> createState() => _FeatureEntryCardState();
}

class _FeatureEntryCardState extends State<FeatureEntryCard> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = widget.onDark;
    final title = dark ? WEAColors.offWhite : WEAColors.primaryText;
    final body = dark
        ? WEAColors.offWhite.withValues(alpha: .80)
        : WEAColors.secondaryText;
    final accent = dark ? WEAColors.accentSoft : WEAColors.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Semantics(
        button: true,
        label: widget.title,
        child: InkWell(
          onTap: () => context.go(widget.route),
          onFocusChange: (focused) => setState(() => _hovering = focused),
          borderRadius: BorderRadius.circular(WEAInsets.radius),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
            padding: const EdgeInsets.all(WEAInsets.lg),
            decoration: BoxDecoration(
              color: dark ? WEAColors.navy : WEAColors.card,
              border: Border.all(
                color: dark
                    ? WEAColors.navy
                    : (_hovering ? WEAColors.accent : WEAColors.border),
              ),
              borderRadius: BorderRadius.circular(WEAInsets.radius),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: WEAColors.navy.withValues(alpha: .12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 20, color: accent),
                    const SizedBox(width: WEAInsets.xs),
                    Expanded(
                      child: Text(
                        widget.eyebrow.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WEAInsets.sm),
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(color: title),
                ),
                const SizedBox(height: WEAInsets.xs),
                Text(
                  widget.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: body),
                ),
                const SizedBox(height: WEAInsets.md),
                Row(
                  children: [
                    Text(
                      widget.actionLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AnimatedSlide(
                      offset: Offset(_hovering ? .35 : 0, 0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 15,
                          color: accent,
                        ),
                      ),
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
