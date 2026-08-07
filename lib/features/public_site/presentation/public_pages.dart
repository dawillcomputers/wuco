import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/responsive/responsive.dart';
import '../../../data/services/public_content_service.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';

class EditorialPage extends StatelessWidget {
  const EditorialPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.intro,
    required this.sections,
    this.ctaLabel,
    this.ctaPath,
  });
  final String eyebrow, title, intro;
  final List<(String, String)> sections;
  final String? ctaLabel, ctaPath;
  @override
  Widget build(BuildContext context) => WEAPublicPage(
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: WEAColors.gold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Text(
                title,
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(intro, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 52),
            ...sections.map((s) => _EditorialBlock(title: s.$1, body: s.$2)),
            if (ctaLabel != null && ctaPath != null) ...[
              const SizedBox(height: 22),
              WEAOutlinedButton(
                label: ctaLabel!,
                onPressed: () => context.go(ctaPath!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _EditorialBlock extends StatelessWidget {
  const _EditorialBlock({required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 26),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: WEAColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

class ProgrammesScreen extends StatefulWidget {
  const ProgrammesScreen({super.key});
  @override
  State<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends State<ProgrammesScreen> {
  String _query = '';
  String _category = 'ALL';
  @override
  Widget build(BuildContext context) {
    final categories = [
      'ALL',
      ...{for (final p in PublicContentService.programmes) p.category},
    ];
    final results = PublicContentService.programmes
        .where(
          (p) =>
              (_category == 'ALL' || p.category == _category) &&
              (p.title.toLowerCase().contains(_query.toLowerCase()) ||
                  p.category.toLowerCase().contains(_query.toLowerCase())),
        )
        .toList();
    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WEASectionHeading(
                eyebrow: 'EXECUTIVE EDUCATION',
                title: 'Programmes for the decisions ahead.',
                description:
                    'Explore focused executive learning in leadership, finance, strategy, policy, trade and transformation.',
              ),
              const SizedBox(height: 32),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search programmes',
                  hintText: 'Leadership, trade, finance…',
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 34),
              ResponsiveBuilder(
                builder: (context, b) {
                  final c = b == WEABreakpoint.mobile
                      ? 1
                      : b == WEABreakpoint.tablet
                      ? 2
                      : 3;
                  return GridView.builder(
                    itemCount: results.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: c,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: b == WEABreakpoint.mobile ? .50 : .54,
                    ),
                    itemBuilder: (_, i) =>
                        WEAProgrammeCard(programme: results[i]),
                  );
                },
              ),
              const SizedBox(height: 60),
              _FeaturedProgramme(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedProgramme extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = PublicContentService.programmes.singleWhere((p) => p.featured);
    return Container(
      padding: const EdgeInsets.all(WEAInsets.xl),
      decoration: BoxDecoration(
        color: WEAColors.deepBlack,
        border: Border.all(color: WEAColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEATURED PROGRAMME',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: WEAColors.gold),
          ),
          const SizedBox(height: 12),
          Text(p.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(p.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          WEAOutlinedButton(
            label: 'EXPLORE PROGRAMME',
            onPressed: () => context.go('/programmes/${p.id}'),
          ),
        ],
      ),
    );
  }
}

class ProgrammeDetailScreen extends StatelessWidget {
  const ProgrammeDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final programme =
        PublicContentService.programmes.where((p) => p.id == id).firstOrNull ??
        PublicContentService.programmes.first;
    return WEAPublicPage(
      child: Column(
        children: [
          WEAContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
              child: ResponsiveBuilder(
                builder: (context, b) {
                  final m = b == WEABreakpoint.mobile;
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programme.category,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: WEAColors.gold,
                              letterSpacing: 1.3,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        programme.title,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        programme.summary,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${programme.duration}  ·  ${programme.deliveryMode}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 28),
                      WEAOutlinedButton(
                        label: 'APPLY FOR THIS PROGRAMME',
                        onPressed: () => context.go('/apply'),
                      ),
                    ],
                  );
                  final visual = WEAVisualImage(
                    imageUrl: programme.imageUrl,
                    alt: programme.title,
                    aspectRatio: 1,
                  );
                  return m
                      ? Column(
                          children: [
                            visual,
                            const SizedBox(height: 32),
                            content,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 64),
                            Expanded(child: visual),
                          ],
                        );
                },
              ),
            ),
          ),
          WEAContainer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: WEAInsets.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _ProgrammeDetailSection(
                    title: 'Overview',
                    body:
                        'A rigorous executive learning experience designed to connect strategic thinking with practical decisions.',
                  ),
                  _ProgrammeDetailSection(
                    title: 'Who should attend',
                    body:
                        'Senior professionals, executives, institutional leaders, entrepreneurs and policy practitioners seeking structured executive development.',
                  ),
                  _ProgrammeDetailSection(
                    title: 'Learning outcomes',
                    body:
                        'Strengthen strategic judgement, apply contemporary frameworks and lead more confidently in complex organisational contexts.',
                  ),
                  _ProgrammeDetailSection(
                    title: 'Format & application information',
                    body:
                        'Delivery formats and admissions dates will be confirmed by WEA. Register interest to receive programme updates.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeDetailSection extends StatelessWidget {
  const _ProgrammeDetailSection({required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) =>
      _EditorialBlock(title: title, body: body);
}

class FacultyScreen extends StatelessWidget {
  const FacultyScreen({super.key});
  @override
  Widget build(BuildContext context) => WEAPublicPage(
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WEASectionHeading(
              eyebrow: 'FACULTY',
              title: 'Experience close to the work.',
            ),
            const SizedBox(height: 14),
            Text(
              'Selected faculty profiles are illustrative until WEA confirms its formal faculty roster.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: const [
                WEAChip(label: 'Leadership'),
                WEAChip(label: 'Trade & Investment'),
                WEAChip(label: 'Policy & Institutions'),
              ],
            ),
            const SizedBox(height: 34),
            ResponsiveBuilder(
              builder: (context, b) {
                final c = b == WEABreakpoint.mobile ? 1 : 3;
                return GridView.count(
                  crossAxisCount: c,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: .38,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 30,
                  children: [
                    for (final member in PublicContentService.faculty)
                      WEAFacultyCard(member: member),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context) => WEAPublicPage(
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WEASectionHeading(
              eyebrow: 'EVENTS',
              title: 'Where executive conversations continue.',
              description:
                  'Forthcoming opportunities are shown as placeholders until WEA publishes its official events calendar.',
            ),
            const SizedBox(height: 36),
            ResponsiveBuilder(
              builder: (context, b) {
                final c = b == WEABreakpoint.mobile ? 1 : 3;
                return GridView.count(
                  crossAxisCount: c,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: .37,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: [
                    for (final event in PublicContentService.events)
                      WEAEventPreview(event: event),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),
            const _EditorialBlock(
              title: 'Past events',
              body:
                  'Past event archives will be published here as WEA’s event programme develops.',
            ),
          ],
        ),
      ),
    ),
  );
}

class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});
  @override
  Widget build(BuildContext context) => WEAPublicPage(
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WEASectionHeading(
              eyebrow: 'POLICY & RESEARCH',
              title: 'Ideas that shape decisions.',
              description:
                  'Policy briefs, research papers, executive insights, trade intelligence and economic analysis.',
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search insights',
              ),
            ),
            const SizedBox(height: 28),
            ...PublicContentService.research.map(
              (r) => _EditorialBlock(
                title: r.title,
                body: '${r.category} · ${r.date}\n\n${r.summary}',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});
  @override
  Widget build(BuildContext context) => EditorialPage(
    eyebrow: 'WUCO PROFESSIONAL NETWORK',
    title: 'A professional identity that continues beyond the classroom.',
    intro:
        'The WUCO Professional Network is being prepared as a connected environment for WEA graduates.',
    sections: const [
      (
        'Why join',
        'Learning becomes a longer professional relationship — one that connects credentials, ideas and opportunity.',
      ),
      (
        'Member benefits',
        'Planned benefits include a lifetime digital alumni profile, verified certificates, badges, roundtables, annual summits, CPD tracking, research access and member networking.',
      ),
      (
        'Digital identity',
        'A future verified learning identity will bring certificates and professional development records together.',
      ),
    ],
    ctaLabel: 'BECOME A MEMBER',
    ctaPath: '/register',
  );
}

class AdmissionsScreen extends StatelessWidget {
  const AdmissionsScreen({super.key});
  @override
  Widget build(BuildContext context) => EditorialPage(
    eyebrow: 'ADMISSIONS',
    title: 'Begin an executive learning journey with purpose.',
    intro:
        'Admissions routes are designed for leaders who want rigorous learning connected to professional impact.',
    sections: const [
      (
        'Who can apply',
        'WEA programmes are designed for senior professionals, executives, entrepreneurs, public officials, trade professionals and institutional leaders.',
      ),
      (
        'Application process',
        'Choose a programme, prepare your professional details, submit an expression of interest and receive admissions guidance from WEA.',
      ),
      (
        'Important information',
        'Programme dates, fees, admission criteria and documentation requirements will be published with each official programme intake.',
      ),
      (
        'Frequently asked questions',
        'Formal admissions FAQs will be added when programme admissions are opened.',
      ),
    ],
    ctaLabel: 'START APPLICATION',
    ctaPath: '/apply',
  );
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});
  @override
  Widget build(BuildContext context) => WEAPublicPage(
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WEASectionHeading(
              eyebrow: 'CONTACT',
              title: 'Speak with WEA.',
              description:
                  'Send an enquiry and the academy team will respond when official contact operations are live.',
            ),
            const SizedBox(height: 36),
            const _PublicForm(
              title: 'General enquiry',
              button: 'SEND ENQUIRY',
              fields: ['Name', 'Email address', 'Organisation', 'Message'],
            ),
            const SizedBox(height: 34),
            const _EditorialBlock(
              title: 'Admissions contact',
              body:
                  'Official admissions contact details will be published by WEA.',
            ),
            const _EditorialBlock(
              title: 'Office information',
              body: 'Official office information will be published by WEA.',
            ),
          ],
        ),
      ),
    ),
  );
}

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key, required this.mode});
  final String mode;
  @override
  Widget build(BuildContext context) {
    final apply = mode == 'apply';
    final register = mode == 'register';
    return WEAPublicPage(
      child: WEAContainer(
        maxWidth: 760,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: _PublicForm(
            title: apply
                ? 'Begin your WEA application'
                : register
                ? 'Create your WEA account'
                : 'Welcome back to WEA',
            button: apply
                ? 'SUBMIT EXPRESSION OF INTEREST'
                : register
                ? 'CREATE ACCOUNT'
                : 'CONTINUE',
            fields: apply
                ? [
                    'Full name',
                    'Email address',
                    'Organisation',
                    'Programme of interest',
                    'Professional profile',
                  ]
                : register
                ? ['Full name', 'Email address', 'Create password']
                : ['Email address', 'Password'],
          ),
        ),
      ),
    );
  }
}

class _PublicForm extends StatelessWidget {
  const _PublicForm({
    required this.title,
    required this.button,
    required this.fields,
  });
  final String title, button;
  final List<String> fields;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(WEAInsets.xl),
    decoration: BoxDecoration(
      color: WEAColors.card,
      border: Border.all(color: WEAColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        for (final field in fields) ...[
          TextField(
            obscureText: field.toLowerCase().contains('password'),
            maxLines: field == 'Message' || field == 'Professional profile'
                ? 4
                : 1,
            decoration: InputDecoration(labelText: field),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'This is a polished public entry form only. Submission and authentication will be enabled in a later module.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        WEAOutlinedButton(
          label: button,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Submission will be enabled in a later module.'),
            ),
          ),
        ),
      ],
    ),
  );
}

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.terms});
  final bool terms;
  @override
  Widget build(BuildContext context) => EditorialPage(
    eyebrow: terms ? 'TERMS' : 'PRIVACY',
    title: terms ? 'Terms of use' : 'Privacy notice',
    intro: terms
        ? 'Draft terms for the WEA public website. Formal terms will be published by the World United Consumer Organisation.'
        : 'Draft privacy notice for the WEA public website. Formal privacy information will be published by the World United Consumer Organisation.',
    sections: terms
        ? const [
            (
              'Website use',
              'Use this website responsibly and do not rely on placeholder programme or event information as a formal offer.',
            ),
            (
              'Future services',
              'Additional learner services will be governed by published terms when they become available.',
            ),
          ]
        : const [
            (
              'Information submitted',
              'Expressions of interest are not processed by this prototype. Formal data handling information will be added before live admissions.',
            ),
            (
              'Your choices',
              'Formal privacy rights, contact details and retention information will be published with the operational website.',
            ),
          ],
  );
}
