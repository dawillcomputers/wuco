import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WEAEntrance extends StatelessWidget {
  const WEAEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => child
      .animate(delay: delay)
      .fadeIn(duration: 420.ms, curve: Curves.easeOut)
      .slideY(begin: .04, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
}

class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    child: AnimatedScale(
      scale: widget.enabled && _hovering ? 1.015 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(
          0,
          widget.enabled && _hovering ? -3 : 0,
          0,
        ),
        child: widget.child,
      ),
    ),
  );
}
