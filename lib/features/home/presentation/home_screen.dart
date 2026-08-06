import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/components/wea_components.dart';
import '../../../shared/layouts/app_shell.dart';
import '../application/hero_slides_provider.dart';
import 'widgets/wea_hero.dart';
import 'widgets/wea_stat_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slides = ref.watch(homepageHeroSlidesProvider);
    return WEAAppShell(
      child: slides.when(
        loading: () => const _HeroLoadingState(),
        error: (_, _) => const _HeroLoadingState(),
        data: (slides) => SingleChildScrollView(
          child: Column(
            children: [
              WEAHero(slides: slides),
              const WEAStatStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroLoadingState extends StatelessWidget {
  const _HeroLoadingState();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 620,
    child: Center(child: WEALoading(label: 'Preparing WEA')),
  );
}
