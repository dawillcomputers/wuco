import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../core/responsive/responsive.dart';
import '../../data/models/public_content.dart';
import '../animations/wea_animations.dart';
import '../components/wea_brand.dart';
import '../components/wea_components.dart';
import '../layouts/app_shell.dart';
import 'wea_grid_background.dart';

class WEAPublicPage extends StatelessWidget {
  const WEAPublicPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => WEAAppShell(
    child: WEAGridBackground(
      child: SingleChildScrollView(
        child: Column(children: [child, const WEAFooter()]),
      ),
    ),
  );
}

class WEASectionHeading extends StatelessWidget {
  const WEASectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.actionLabel,
    this.actionPath,
  });
  final String eyebrow;
  final String title;
  final String? description;
  final String? actionLabel;
  final String? actionPath;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: WEAColors.accent,
                letterSpacing: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            if (description != null) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ],
        ),
      ),
      if (actionLabel != null &&
          actionPath != null &&
          !WEAResponsive.isMobile(context))
        WEATextButton(
          label: '$actionLabel  →',
          onPressed: () => context.go(actionPath!),
        ),
    ],
  );
}

class WEAVisualImage extends StatelessWidget {
  const WEAVisualImage({
    super.key,
    required this.imageUrl,
    required this.alt,
    this.aspectRatio = 4 / 3,
    this.overlay = true,
  });
  final String imageUrl;
  final String alt;
  final double aspectRatio;
  final bool overlay;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(WEAInsets.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            semanticLabel: alt,
            errorBuilder: (_, _, _) => const _ImageFallback(),
          ),
          if (overlay)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // A light navy scrim for depth; the type sits below the
                  // image rather than on it, so it stays deliberately gentle.
                  colors: [Color(0x000A1E3D), Color(0x2E0A1E3D)],
                ),
              ),
            ),
        ],
      ),
    ),
  ).animate().fadeIn(duration: 500.ms);
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [WEAColors.elevated, WEAColors.background],
      ),
    ),
  );
}

class WEAProgrammeCard extends StatelessWidget {
  const WEAProgrammeCard({super.key, required this.programme});
  final Programme programme;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Container(
      decoration: BoxDecoration(
        color: WEAColors.card.withValues(alpha: .84),
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WEAVisualImage(
            imageUrl: programme.imageUrl,
            alt: programme.title,
            aspectRatio: 16 / 8.5,
          ),
          Padding(
            padding: const EdgeInsets.all(WEAInsets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programme.category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  programme.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  programme.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      programme.duration,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Text('·'),
                    Text(
                      programme.deliveryMode,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                WEATextButton(
                  label: 'VIEW DETAILS  →',
                  onPressed: () => context.go('/programmes/${programme.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WEAFacultyCard extends StatelessWidget {
  const WEAFacultyCard({super.key, required this.member});
  final FacultyMember member;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WEAVisualImage(
          imageUrl: member.imageUrl,
          alt: member.expertise,
          aspectRatio: .94,
        ),
        const SizedBox(height: 16),
        Container(height: 1, width: 34, color: WEAColors.accent),
        const SizedBox(height: 12),
        Text(member.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          member.role,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: WEAColors.accent),
        ),
        const SizedBox(height: 8),
        Text(member.expertise, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(member.note, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class WEAEventPreview extends StatelessWidget {
  const WEAEventPreview({super.key, required this.event});
  final WEAEvent event;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: WEAColors.border),
        color: WEAColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WEAVisualImage(
            imageUrl: event.imageUrl,
            alt: event.title,
            aspectRatio: 16 / 8,
          ),
          Padding(
            padding: const EdgeInsets.all(WEAInsets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.date,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  event.format,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WEAFooter extends StatelessWidget {
  const WEAFooter({super.key});

  /// Links grouped the way a visitor thinks about them, rather than one long
  /// undifferentiated row.
  static const _groups = <(String, List<(String, String)>)>[
    (
      'Study',
      [
        ('Programmes', '/programmes'),
        ('Admissions', '/admissions'),
        ('Apply', '/apply'),
      ],
    ),
    (
      'Institution',
      [
        ('About WEA', '/about'),
        ('Faculty', '/faculty'),
        ('Research', '/research'),
      ],
    ),
    (
      'Community',
      [
        ('Events', '/events'),
        ('Professional Network', '/professional-network'),
        ('Contact', '/contact'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: WEAColors.navy),
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.only(top: 72, bottom: 32),
        child: ResponsiveBuilder(
          builder: (context, breakpoint) {
            final isMobile = breakpoint == WEABreakpoint.mobile;
            final isTablet = breakpoint == WEABreakpoint.tablet;
            final theme = Theme.of(context);

            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEABrandLockup(height: isMobile ? 92 : 112, onDark: true),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    "Africa's Executive Academy for Leadership, Trade, "
                    'Investment and Professional Development.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: WEAColors.offWhite.withValues(alpha: .72),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'BACKED BY WUCO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.accentSoft,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            );

            final columns = [
              for (final group in _groups)
                _FooterColumn(title: group.$1, links: group.$2),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 40),
                      for (final column in columns)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: column,
                        ),
                    ],
                  )
                else if (isTablet)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 44),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final column in columns)
                            Expanded(child: column),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: identity),
                      const SizedBox(width: 48),
                      for (final column in columns)
                        Expanded(flex: 3, child: column),
                    ],
                  ),
                const SizedBox(height: 48),
                Container(
                  height: 1,
                  color: WEAColors.offWhite.withValues(alpha: .14),
                ),
                const SizedBox(height: 20),
                _LegalBar(isMobile: isMobile),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<(String, String)> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.offWhite,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final link in links)
          _FooterLink(label: link.$1, path: link.$2),
      ],
    );
  }
}

/// Quiet by default, brightening on hover — no layout shift either way.
class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label, required this.path});

  final String label;
  final String path;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    child: GestureDetector(
      onTap: () => context.go(widget.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: _hovering
                ? WEAColors.accentSoft
                : WEAColors.offWhite.withValues(alpha: .70),
          ),
          child: Text(widget.label),
        ),
      ),
    ),
  );
}

class _LegalBar extends StatelessWidget {
  const _LegalBar({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copyright = Text(
      '© 2026 WUCO Executive Academy. A division of the World United Consumer Organisation.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: WEAColors.offWhite.withValues(alpha: .55),
      ),
    );
    final legal = Wrap(
      spacing: 20,
      children: const [
        _FooterLink(label: 'Privacy', path: '/privacy'),
        _FooterLink(label: 'Terms', path: '/terms'),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [legal, const SizedBox(height: 8), copyright],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: copyright),
        const SizedBox(width: 24),
        legal,
      ],
    );
  }
}
