import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue_models.dart';
import 'widgets/catalogue_cards.dart';

/// A single programme's public page.
class ProgrammeScreen extends ConsumerWidget {
  const ProgrammeScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programmeDetailProvider(slug));

    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: CatalogueAsync(
            value: detail,
            onRetry: () => ref.invalidate(programmeDetailProvider(slug)),
            data: (data) => _ProgrammeBody(detail: data),
          ),
        ),
      ),
    );
  }
}

class _ProgrammeBody extends StatelessWidget {
  const _ProgrammeBody({required this.detail});

  final ProgrammeDetail detail;

  @override
  Widget build(BuildContext context) {
    final programme = detail.programme;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final aside = _RegistrationPanel(programme: programme);

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CatalogueImage(url: programme.imageUrl, aspectRatio: 21 / 8),
        const SizedBox(height: WEAInsets.xl),
        if (programme.description.isNotEmpty) ...[
          Text(programme.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: WEAInsets.xl),
        ],
        if (programme.learningOutcomes.isNotEmpty) ...[
          _Section(
            title: 'What you will learn',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final outcome in programme.learningOutcomes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WEAInsets.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 17,
                            color: WEAColors.accent,
                          ),
                        ),
                        const SizedBox(width: WEAInsets.xs),
                        Expanded(
                          child: Text(
                            outcome,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.xl),
        ],
        if (programme.whoShouldAttend.isNotEmpty) ...[
          _Section(
            title: 'Who should attend',
            child: Text(
              programme.whoShouldAttend,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: WEAInsets.xl),
        ],
        if (detail.modules.isNotEmpty) ...[
          _Section(
            title: 'Programme structure',
            child: Column(
              children: [
                for (final module in detail.modules)
                  _ModuleRow(module: module),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.xl),
        ],
        if (detail.faculty.isNotEmpty) ...[
          _Section(
            title: 'Faculty',
            child: Column(
              children: [
                for (final member in detail.faculty)
                  _FacultyRow(member: member),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.xl),
        ],
        if (detail.schedule.isNotEmpty) ...[
          _Section(
            title: 'Live executive sessions',
            child: Column(
              children: [
                for (final entry in detail.schedule)
                  _ScheduleRow(entry: entry),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.xl),
        ],
        _Section(
          title: 'Certification',
          child: Text(
            programme.certificateAward.isEmpty
                ? 'Participants who complete the programme receive a WUCO Executive Academy certificate.'
                : 'On successful completion you receive the ${programme.certificateAward}, issued by WUCO Executive Academy and verifiable through your WEA digital credentials.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (programme.eligibility.isNotEmpty) ...[
          const SizedBox(height: WEAInsets.xl),
          _Section(
            title: 'Eligibility',
            child: Text(
              programme.eligibility,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WEATextButton(
          label: '← ${programme.areaTitle}',
          onPressed: () => context.go('/programmes/area/${programme.areaSlug}'),
        ),
        const SizedBox(height: WEAInsets.sm),
        WEASectionHeading(
          eyebrow: programme.typeTitle.toUpperCase(),
          title: programme.title,
          description: programme.summary,
        ),
        const SizedBox(height: WEAInsets.xl),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: WEAInsets.xl),
              Expanded(flex: 4, child: aside),
            ],
          )
        else ...[
          aside,
          const SizedBox(height: WEAInsets.xl),
          main,
        ],
      ],
    );
  }
}

/// Programme facts and the call to register.
class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({required this.programme});

  final CatalogueProgramme programme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <(String, String)>[
      ('Duration', programme.durationLabel),
      ('Delivery', programme.deliveryMode),
      ('Level', programme.level),
      ('Language', programme.language),
      if (programme.certificateAward.isNotEmpty)
        ('Certificate', programme.certificateAward),
      if (programme.startDate != null && programme.startDate!.isNotEmpty)
        ('Starts', programme.startDate!),
      if (programme.applicationDeadline != null &&
          programme.applicationDeadline!.isNotEmpty)
        ('Applications close', programme.applicationDeadline!),
      if (programme.cpdPoints > 0) ('CPD points', '${programme.cpdPoints}'),
    ];

    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TUITION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(programme.tuitionLabel, style: theme.textTheme.headlineSmall),
          if (programme.tuitionNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(programme.tuitionNote, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: WEAInsets.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: programme.registrationOpen
                  ? () => context.go('/register/${programme.slug}')
                  : null,
              child: Text(
                programme.registrationOpen
                    ? 'REGISTER NOW'
                    : 'REGISTRATION CLOSED',
              ),
            ),
          ),
          if (!programme.registrationOpen) ...[
            const SizedBox(height: WEAInsets.xs),
            Text(
              'Registration for this intake has closed. Contact the programme office to be told when the next one opens.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: WEAInsets.lg),
          const Divider(),
          const SizedBox(height: WEAInsets.sm),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: WEAInsets.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: WEAColors.mutedText,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: WEAInsets.md),
      child,
    ],
  );
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final ProgrammeModuleOutline module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.sm),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              module.number.toString().padLeft(2, '0'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: WEAColors.accent,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: theme.textTheme.titleMedium),
                if (module.summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(module.summary, style: theme.textTheme.bodySmall),
                ],
                if (module.durationLabel.isNotEmpty ||
                    module.lessons.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (module.durationLabel.isNotEmpty) module.durationLabel,
                      if (module.lessons.isNotEmpty)
                        '${module.lessons.length} lessons',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacultyRow extends StatelessWidget {
  const _FacultyRow({required this.member});

  final FacultyProfile member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: WEAColors.elevated,
            foregroundImage: member.imageUrl == null
                ? null
                : NetworkImage(member.imageUrl!),
            child: const Icon(Icons.person_outline, color: WEAColors.mutedText),
          ),
          const SizedBox(width: WEAInsets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: theme.textTheme.titleMedium),
                Text(
                  [
                    if (member.programmeRole.isNotEmpty) member.programmeRole,
                    if (member.roleTitle.isNotEmpty) member.roleTitle,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (member.bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(member.bio, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.entry});

  final ProgrammeScheduleEntry entry;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _when {
    final start = entry.startsAt;
    if (start == null) return 'Date to be confirmed';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';
    return '${start.day} ${_months[start.month - 1]} ${start.year} · $time '
        '${entry.timezone}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.sm),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_outlined,
            size: 18,
            color: WEAColors.accent,
          ),
          const SizedBox(width: WEAInsets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: theme.textTheme.titleMedium),
                Text(_when, style: theme.textTheme.bodySmall),
                if (entry.facultyName.isNotEmpty)
                  Text(entry.facultyName, style: theme.textTheme.bodySmall),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.notes, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
