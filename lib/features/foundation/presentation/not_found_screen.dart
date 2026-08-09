import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/animations/wea_animations.dart';
import '../../../shared/components/wea_components.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: WEAContainer(
      child: Center(
        child: WEAEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '404',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: WEAColors.accent,
                  fontSize: 88,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'The executive education resource you requested is not available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              WEAButton(
                label: 'Return Home',
                icon: Icons.home_outlined,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
