import '../models/hero_slide.dart';
import '../repositories/hero_slide_repository.dart';

/// Temporary development implementation.
///
/// It deliberately provides slots rather than final photographs: production
/// will replace this service with a Supabase-backed repository managed by the
/// Super Admin. The validation preserves the homepage contract of exactly
/// three active slides.
class DevelopmentHeroSlideRepository implements HeroSlideRepository {
  const DevelopmentHeroSlideRepository();

  @override
  Future<List<HeroSlide>> getActiveHomepageSlides() async {
    const slides = [
      HeroSlide(
        id: 'hero-slot-1',
        isActive: true,
        sortOrder: 1,
        duration: Duration(seconds: 7),
        overlayStrength: HeroOverlayStrength.strong,
      ),
      HeroSlide(
        id: 'hero-slot-2',
        isActive: true,
        sortOrder: 2,
        duration: Duration(seconds: 7),
        overlayStrength: HeroOverlayStrength.strong,
      ),
      HeroSlide(
        id: 'hero-slot-3',
        isActive: true,
        sortOrder: 3,
        duration: Duration(seconds: 7),
        overlayStrength: HeroOverlayStrength.medium,
      ),
    ];
    return _validate(slides);
  }

  List<HeroSlide> _validate(List<HeroSlide> slides) {
    final active = slides.where((slide) => slide.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (active.length != 3) {
      throw StateError(
        'The WEA homepage requires exactly three active hero slides.',
      );
    }
    return List.unmodifiable(active);
  }
}
