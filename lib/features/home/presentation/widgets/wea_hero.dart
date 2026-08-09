import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../data/models/hero_slide.dart';
import '../../../../shared/components/wea_components.dart';
import '../../../../shared/widgets/wea_grid_background.dart';

class WEAHero extends StatelessWidget {
  const WEAHero({super.key, required this.slides});

  final List<HeroSlide> slides;

  @override
  Widget build(BuildContext context) => WEAHeroSlider(slides: slides);
}

class WEAHeroSlider extends StatefulWidget {
  const WEAHeroSlider({super.key, required this.slides});

  final List<HeroSlide> slides;

  @override
  State<WEAHeroSlider> createState() => _WEAHeroSliderState();
}

class _WEAHeroSliderState extends State<WEAHeroSlider> {
  Timer? _timer;
  var _activeIndex = 0;
  var _reducedMotion = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant WEAHeroSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides != widget.slides) {
      _activeIndex = 0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.slides.length < 2 || _reducedMotion) {
      return;
    }
    _timer = Timer.periodic(widget.slides[_activeIndex].duration, (_) {
      if (mounted) {
        setState(
          () => _activeIndex = (_activeIndex + 1) % widget.slides.length,
        );
      }
    });
  }

  void _selectSlide(int index) {
    if (index == _activeIndex) {
      return;
    }
    setState(() => _activeIndex = index);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.slides.length == 3,
      'WEA hero must render exactly three slides.',
    );
    final breakpoint = WEAResponsive.breakpointOf(
      MediaQuery.sizeOf(context).width,
    );
    final isMobile = breakpoint == WEABreakpoint.mobile;
    final height = isMobile
        ? 620.0
        : (MediaQuery.sizeOf(context).height * .78).clamp(440.0, 820.0);
    final activeSlide = widget.slides[_activeIndex];

    return SizedBox(
      height: height,
      child: WEAGridBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 1000),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              ),
              child: _HeroSlideBackground(
                key: ValueKey(activeSlide.id),
                slide: activeSlide,
                variant: _activeIndex,
              ),
            ),
            WEAHeroOverlay(strength: activeSlide.overlayStrength),
            _HeroContent(isMobile: isMobile),
            Positioned(
              left: isMobile ? 20 : 32,
              right: isMobile ? 20 : 32,
              bottom: isMobile ? 24 : 30,
              child: WEAContainer(
                maxWidth: WEAMaxWidths.content,
                child: _HeroFooter(
                  activeIndex: _activeIndex,
                  onSelect: _selectSlide,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlideBackground extends StatelessWidget {
  const _HeroSlideBackground({
    super.key,
    required this.slide,
    required this.variant,
  });

  final HeroSlide slide;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final imageUrl = slide.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        alignment: slide.focalPoint,
        errorBuilder: (_, _, _) => _HeroSlotCanvas(variant: variant),
      );
    }
    return _HeroSlotCanvas(variant: variant);
  }
}

class _HeroSlotCanvas extends StatelessWidget {
  const _HeroSlotCanvas({required this.variant});

  final int variant;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeroSlotPainter(variant),
    child: const SizedBox.expand(),
  );
}

class _HeroSlotPainter extends CustomPainter {
  const _HeroSlotPainter(this.variant);

  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final colours = [
      const Color(0xFF16386B),
      const Color(0xFF102B57),
      const Color(0xFF1B4A80),
    ];
    final base = colours[variant % colours.length];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [base, WEAColors.navyDeep],
        ).createShader(Offset.zero & size),
    );
    final silhouette = Paint()
      ..color = WEAColors.navyDeep.withValues(alpha: .45);
    final circleCenter = Offset(
      size.width * (.76 - variant * .08),
      size.height * .45,
    );
    canvas.drawCircle(circleCenter, size.shortestSide * .34, silhouette);
    final linePaint = Paint()
      ..color = WEAColors.offWhite.withValues(alpha: .045)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = size.height * (.15 + index * .18);
      canvas.drawLine(
        Offset(size.width * .36, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroSlotPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class WEAHeroOverlay extends StatelessWidget {
  const WEAHeroOverlay({super.key, required this.strength});

  final HeroOverlayStrength strength;

  @override
  Widget build(BuildContext context) {
    final navyOpacity = switch (strength) {
      HeroOverlayStrength.light => .52,
      HeroOverlayStrength.medium => .62,
      HeroOverlayStrength.strong => .72,
    };
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: WEAColors.navy.withValues(alpha: navyOpacity)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  WEAColors.navyDeep.withValues(alpha: .90),
                  WEAColors.navyDeep.withValues(alpha: .56),
                  WEAColors.navyDeep.withValues(alpha: .18),
                ],
                stops: const [0, .52, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  WEAColors.accent.withValues(alpha: .10),
                  Colors.transparent,
                  WEAColors.navyDeep.withValues(alpha: .72),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: WEAContainer(
      maxWidth: WEAMaxWidths.content,
      child: Padding(
        padding: EdgeInsets.only(bottom: isMobile ? 20 : 34),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth > 700 ? 700 : constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, width: 46, color: WEAColors.accentSoft),
                  SizedBox(height: isMobile ? 22 : 28),
                  Text(
                    "Where Africa's\nLeaders Are Formed",
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      // The hero sits on a navy overlay, so it opts out of the
                      // light theme's navy type colour.
                      color: WEAColors.offWhite,
                      fontSize: isMobile ? 46 : 72,
                      height: .99,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.85,
                    ),
                  ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut),
                  SizedBox(height: isMobile ? 22 : 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Text(
                      'Executive certificate programmes of the highest academic rigour, '
                      'backed by the institutional authority of the World United Consumer Organisation.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: WEAColors.offWhite.withValues(alpha: .86),
                        height: 1.65,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 30 : 36),
                  WEAOutlinedButton(
                    label: 'EXPLORE PROGRAMMES',
                    onPressed: () => context.go('/programmes'),
                    onDark: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HeroFooter extends StatelessWidget {
  const _HeroFooter({required this.activeIndex, required this.onSelect});

  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '0${activeIndex + 1}  /  03',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: WEAColors.offWhite.withValues(alpha: .82),
          letterSpacing: 1.35,
        ),
      ),
      const SizedBox(width: 18),
      for (var index = 0; index < 3; index++)
        GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 1,
            width: index == activeIndex ? 34 : 16,
            margin: const EdgeInsets.only(right: 7),
            color: index == activeIndex
                ? WEAColors.accentSoft
                : WEAColors.offWhite.withValues(alpha: .35),
          ),
        ),
    ],
  );
}
