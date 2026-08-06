import '../models/hero_slide.dart';

abstract interface class HeroSlideRepository {
  /// Returns exactly the three active homepage slots in their configured order.
  Future<List<HeroSlide>> getActiveHomepageSlides();
}
