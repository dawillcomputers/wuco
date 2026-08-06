import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/hero_slide.dart';
import '../../../data/repositories/hero_slide_repository.dart';
import '../../../data/services/hero_slide_service.dart';

final heroSlideRepositoryProvider = Provider<HeroSlideRepository>(
  (ref) => const DevelopmentHeroSlideRepository(),
);

final homepageHeroSlidesProvider = FutureProvider<List<HeroSlide>>(
  (ref) => ref.watch(heroSlideRepositoryProvider).getActiveHomepageSlides(),
);
