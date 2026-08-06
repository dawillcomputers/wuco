import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/layouts/app_shell.dart';
import '../../../shared/widgets/wea_grid_background.dart';

/// Development-only palette and component reference. It is intentionally not
/// linked from the public navigation.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) => WEAAppShell(
    child: WEAGridBackground(
      child: SingleChildScrollView(
        child: WEAContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESIGN SYSTEM',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: WEAColors.gold,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'WEA Visual Foundation',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Development-only reference for the editorial WEA interface.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const _ShowcaseSection(
                  title: 'Colour balance',
                  child: _ColourTokens(),
                ),
                _ShowcaseSection(
                  title: 'Editorial typography',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Where Africa's Leaders Are Formed",
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Executive education with clarity, authority and restraint.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'LABEL / METADATA / NAVIGATION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: WEAColors.gold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _ShowcaseSection(
                  title: 'Actions',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      WEAButton(label: 'Primary action', onPressed: () {}),
                      WEAOutlinedButton(
                        label: 'EXPLORE PROGRAMMES',
                        onPressed: () {},
                      ),
                      WEATextButton(
                        label: 'Secondary action',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                _ShowcaseSection(
                  title: 'Surfaces and form controls',
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      SizedBox(
                        width: 300,
                        child: WEACard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restrained card',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A quiet surface with a fine border and no inflated decoration.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            hintText: 'you@example.com',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, width: 36, color: WEAColors.gold),
        const SizedBox(height: 14),
        Text(
          title.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );
}

class _ColourTokens extends StatelessWidget {
  const _ColourTokens();

  static const _tokens = [
    ('Black', WEAColors.background),
    ('Surface', WEAColors.surface),
    ('Card', WEAColors.card),
    ('Gold', WEAColors.gold),
    ('Off white', WEAColors.offWhite),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final token in _tokens)
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: token.$2,
                  border: Border.all(color: WEAColors.border),
                ),
              ),
              const SizedBox(height: 8),
              Text(token.$1, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
    ],
  );
}
