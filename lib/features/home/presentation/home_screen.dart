import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/responsive/responsive.dart';
import '../../../shared/animations/wea_animations.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/layouts/app_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => WEAAppShell(
    child: WEAContainer(
      child: ResponsiveBuilder(
        builder: (context, breakpoint) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: WEAEntrance(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: breakpoint == WEABreakpoint.mobile ? 76 : 132,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WEABadge(
                      label: 'EXECUTIVE EDUCATION · AFRICA & THE WORLD',
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'WUCO\nEXECUTIVE ACADEMY',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: breakpoint == WEABreakpoint.mobile ? 42 : 62,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'WEA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: WEAColors.brightGold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Empowering Africa's Leaders. Shaping Global Excellence.",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: WEAColors.secondaryText),
                    ),
                    const SizedBox(height: 32),
                    WEAButton(
                      label: 'Explore Programmes',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/programmes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
