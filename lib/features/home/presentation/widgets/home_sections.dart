import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../data/services/public_content_service.dart';
import '../../../../shared/components/wea_components.dart';
import '../../../../shared/widgets/wea_public_widgets.dart';

class HomePublicSections extends StatelessWidget {
  const HomePublicSections({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: const [
      _AboutIntroduction(),
      _ProgrammeShowcase(),
      _WhyWEA(),
      _TradeFeature(),
      _FacultyShowcase(),
      _NetworkFeature(),
      _MentorFeature(),
      _Credibility(),
      _EventsShowcase(),
      _ResearchShowcase(),
      _ApplyFeature(),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.dark = false});
  final Widget child;
  final bool dark;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: dark
        ? const BoxDecoration(
            color: WEAColors.deepBlack,
            border: Border(
              top: BorderSide(color: WEAColors.border),
              bottom: BorderSide(color: WEAColors.border),
            ),
          )
        : const BoxDecoration(),
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
        child: child,
      ),
    ),
  );
}

class _AboutIntroduction extends StatelessWidget {
  const _AboutIntroduction();
  @override
  Widget build(BuildContext context) => _Section(
    child: ResponsiveBuilder(
      builder: (context, breakpoint) {
        final stack = breakpoint == WEABreakpoint.mobile;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WEASectionHeading(
              eyebrow: 'WUCO EXECUTIVE ACADEMY',
              title: "Executive learning for leaders shaping Africa's future.",
            ),
            const SizedBox(height: 22),
            Text(
              'WEA provides rigorous executive education, professional certification and policy capacity development for leaders operating across Africa and the global economy.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: const [
                'Senior professionals',
                'Executives',
                'Government officials',
                'Entrepreneurs',
                'Policy leaders',
                'Investors',
                'Trade professionals',
                'Institutional leaders',
              ].map((label) => WEAChip(label: label)).toList(),
            ),
            const SizedBox(height: 28),
            WEAOutlinedButton(
              label: 'DISCOVER WEA',
              onPressed: () => context.go('/about'),
            ),
          ],
        );
        final image = const WEAVisualImage(
          imageUrl:
              'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1200&q=82',
          alt: 'Executive leaders in discussion',
          aspectRatio: 4 / 4.3,
        );
        return stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 32), image],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 11, child: text),
                  const SizedBox(width: 64),
                  const Expanded(flex: 9, child: _AboutImage()),
                ],
              );
      },
    ),
  );
}

class _AboutImage extends StatelessWidget {
  const _AboutImage();
  @override
  Widget build(BuildContext context) => const WEAVisualImage(
    imageUrl:
        'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1200&q=82',
    alt: 'Executive leaders in discussion',
    aspectRatio: 4 / 4.3,
  );
}

class _ProgrammeShowcase extends StatelessWidget {
  const _ProgrammeShowcase();
  @override
  Widget build(BuildContext context) => _Section(
    dark: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WEASectionHeading(
          eyebrow: 'EXECUTIVE EDUCATION',
          title: 'Programmes designed for leaders.',
          description:
              'Explore rigorous executive programmes designed around leadership, finance, strategy, policy, trade and transformation.',
          actionLabel: 'VIEW ALL PROGRAMMES',
          actionPath: '/programmes',
        ),
        const SizedBox(height: 40),
        ResponsiveBuilder(
          builder: (context, breakpoint) {
            final columns = breakpoint == WEABreakpoint.mobile
                ? 1
                : breakpoint == WEABreakpoint.tablet
                ? 2
                : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: breakpoint == WEABreakpoint.mobile
                    ? .50
                    : .54,
              ),
              itemBuilder: (_, index) => WEAProgrammeCard(
                programme: PublicContentService.programmes[index],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        if (WEAResponsive.isMobile(context))
          WEATextButton(
            label: 'VIEW ALL PROGRAMMES  →',
            onPressed: () => context.go('/programmes'),
          ),
      ],
    ),
  );
}

class _WhyWEA extends StatelessWidget {
  const _WhyWEA();
  @override
  Widget build(BuildContext context) => _Section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WEASectionHeading(
          eyebrow: 'WHY WEA',
          title: 'Built for decisions that matter.',
        ),
        const SizedBox(height: 38),
        ResponsiveBuilder(
          builder: (context, breakpoint) {
            final cols = breakpoint == WEABreakpoint.mobile ? 1 : 2;
            const values = [
              (
                '01',
                'Institutional Authority',
                'Backed by the World United Consumer Organisation.',
              ),
              (
                '02',
                'Rigorous Curriculum',
                'Executive learning designed around real-world leadership challenges.',
              ),
              (
                '03',
                'Distinguished Faculty',
                'Learn from experienced professionals, academics and practitioners.',
              ),
              (
                '04',
                'Pan-African Perspective',
                "Designed around Africa's evolving economic and institutional landscape.",
              ),
              (
                '05',
                'Practical Application',
                'Programmes focus on decisions, strategy and measurable professional impact.',
              ),
              (
                '06',
                'Professional Network',
                'Learning continues beyond the classroom.',
              ),
            ];
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: breakpoint == WEABreakpoint.mobile ? 1.2 : 1.7,
              children: [
                for (final value in values)
                  _WhyItem(number: value.$1, title: value.$2, body: value.$3),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _WhyItem extends StatelessWidget {
  const _WhyItem({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number, title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 28, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: WEAColors.gold),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TradeFeature extends StatelessWidget {
  const _TradeFeature();
  @override
  Widget build(BuildContext context) => _Section(
    dark: true,
    child: ResponsiveBuilder(
      builder: (context, breakpoint) {
        final isMobile = breakpoint == WEABreakpoint.mobile;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIGNATURE PROGRAMME',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: WEAColors.gold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Africa Trade & Investment Executive Certificate Programme',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(
              "Unlocking Africa's Trade and Investment Potential through AfCFTA, Regional Integration and Sustainable Economic Development.",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                'AfCFTA',
                'Cross-Border Trade',
                'Regional Integration',
                'Investment Promotion',
                'Digital Trade',
                'Economic Diplomacy',
              ].map((label) => WEAChip(label: label)).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              '16 WEEKS  ·  BLENDED',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 26),
            WEAOutlinedButton(
              label: 'EXPLORE PROGRAMME',
              onPressed: () =>
                  context.go('/programmes/africa-trade-investment'),
            ),
          ],
        );
        final image = const WEAVisualImage(
          imageUrl:
              'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?auto=format&fit=crop&w=1300&q=82',
          alt: 'African trade and investment',
          aspectRatio: 1,
        );
        return isMobile
            ? Column(children: [image, const SizedBox(height: 32), content])
            : Row(
                children: [
                  const Expanded(child: _TradeImage()),
                  const SizedBox(width: 64),
                  Expanded(child: content),
                ],
              );
      },
    ),
  );
}

class _TradeImage extends StatelessWidget {
  const _TradeImage();
  @override
  Widget build(BuildContext context) => const WEAVisualImage(
    imageUrl:
        'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?auto=format&fit=crop&w=1300&q=82',
    alt: 'African trade and investment',
    aspectRatio: 1,
  );
}

class _FacultyShowcase extends StatelessWidget {
  const _FacultyShowcase();
  @override
  Widget build(BuildContext context) => _Section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WEASectionHeading(
          eyebrow: 'FACULTY OF DISTINCTION',
          title: 'Learn from practitioners who understand the real world.',
          actionLabel: 'VIEW FACULTY',
          actionPath: '/faculty',
        ),
        const SizedBox(height: 36),
        ResponsiveBuilder(
          builder: (context, b) {
            final c = b == WEABreakpoint.mobile ? 1 : 3;
            return GridView.count(
              crossAxisCount: c,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 24,
              mainAxisSpacing: 32,
              childAspectRatio: .38,
              children: [
                for (final member in PublicContentService.faculty)
                  WEAFacultyCard(member: member),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _NetworkFeature extends StatelessWidget {
  const _NetworkFeature();
  @override
  Widget build(BuildContext context) => _Section(
    dark: true,
    child: _SplitFeature(
      eyebrow: 'WUCO PROFESSIONAL NETWORK',
      title: 'Your learning does not end with your certificate.',
      body:
          'The WUCO Professional Network connects WEA graduates beyond individual programmes — with digital identity, verified learning records, executive conversations and research access.',
      button: 'JOIN THE PROFESSIONAL NETWORK',
      path: '/professional-network',
      image:
          'https://images.unsplash.com/photo-1528605248644-14dd04022da1?auto=format&fit=crop&w=1200&q=82',
      alt: 'Professional networking event',
    ),
  );
}

class _MentorFeature extends StatelessWidget {
  const _MentorFeature();
  @override
  Widget build(BuildContext context) => _Section(
    child: _SplitFeature(
      reverse: true,
      eyebrow: 'WEA AI MENTOR',
      title: 'Your executive learning companion.',
      body:
          'A future WEA AI Mentor will help learners explain difficult concepts, prepare for certification, summarize lessons and plan their professional pathway. This is a public introduction; no AI functionality is enabled yet.',
      button: 'DISCOVER WEA AI MENTOR',
      path: '/about',
      image:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=82',
      alt: 'Technology and digital learning',
    ),
  );
}

class _SplitFeature extends StatelessWidget {
  const _SplitFeature({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.button,
    required this.path,
    required this.image,
    required this.alt,
    this.reverse = false,
  });
  final String eyebrow, title, body, button, path, image, alt;
  final bool reverse;
  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
    builder: (context, b) {
      final m = b == WEABreakpoint.mobile;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: WEAColors.gold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 26),
          WEAOutlinedButton(label: button, onPressed: () => context.go(path)),
        ],
      );
      final imageWidget = WEAVisualImage(
        imageUrl: image,
        alt: alt,
        aspectRatio: 1.22,
      );
      if (m) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [imageWidget, const SizedBox(height: 32), content],
        );
      }
      return Row(
        children: reverse
            ? [
                Expanded(child: content),
                const SizedBox(width: 64),
                Expanded(child: imageWidget),
              ]
            : [
                Expanded(child: imageWidget),
                const SizedBox(width: 64),
                Expanded(child: content),
              ],
      );
    },
  );
}

class _Credibility extends StatelessWidget {
  const _Credibility();
  @override
  Widget build(BuildContext context) => _Section(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          children: [
            Text(
              'INSTITUTIONAL CREDIBILITY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: WEAColors.gold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Backed by the World United Consumer Organisation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'WEA brings institutional authority, executive standards, professional development and a Pan-African perspective to every learning experience.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EventsShowcase extends StatelessWidget {
  const _EventsShowcase();
  @override
  Widget build(BuildContext context) => _Section(
    dark: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WEASectionHeading(
          eyebrow: 'UPCOMING EVENTS',
          title: 'Conversations for leaders in motion.',
          actionLabel: 'VIEW ALL EVENTS',
          actionPath: '/events',
        ),
        const SizedBox(height: 36),
        ResponsiveBuilder(
          builder: (context, b) {
            final c = b == WEABreakpoint.mobile ? 1 : 3;
            return GridView.count(
              crossAxisCount: c,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: .37,
              children: [
                for (final e in PublicContentService.events)
                  WEAEventPreview(event: e),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ResearchShowcase extends StatelessWidget {
  const _ResearchShowcase();
  @override
  Widget build(BuildContext context) => _Section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WEASectionHeading(
          eyebrow: 'POLICY & RESEARCH',
          title: 'Ideas that shape decisions.',
          description:
              'Policy briefs, research papers, executive insights, trade intelligence and leadership perspectives.',
          actionLabel: 'EXPLORE RESEARCH',
          actionPath: '/research',
        ),
        const SizedBox(height: 30),
        ...PublicContentService.research.map(
          (r) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WEAColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    r.category,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: WEAColors.gold),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(r.date, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ApplyFeature extends StatelessWidget {
  const _ApplyFeature();
  @override
  Widget build(BuildContext context) => _Section(
    dark: true,
    child: Container(
      padding: const EdgeInsets.all(WEAInsets.xxl),
      decoration: BoxDecoration(
        border: Border.all(color: WEAColors.border),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1521737711867-e3b97375f902?auto=format&fit=crop&w=1400&q=82',
          ),
          fit: BoxFit.cover,
          opacity: .18,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADMISSIONS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: WEAColors.gold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to lead with greater authority?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              "Apply to WUCO Executive Academy and join a community of professionals committed to excellence, leadership and Africa's future.",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WEAOutlinedButton(
                label: 'APPLY NOW',
                onPressed: () => context.go('/apply'),
              ),
              WEATextButton(
                label: 'EXPLORE PROGRAMMES',
                onPressed: () => context.go('/programmes'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
