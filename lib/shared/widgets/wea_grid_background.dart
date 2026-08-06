import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';

class WEAGridBackground extends StatelessWidget {
  const WEAGridBackground({super.key, required this.child, this.opacity = .55});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isMobile = WEAResponsive.isMobile(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: WEAColors.background),
        IgnorePointer(
          child: CustomPaint(
            painter: _GridPainter(
              cellSize: isMobile ? 72 : 96,
              opacity: isMobile ? opacity * .65 : opacity,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.cellSize, required this.opacity});

  final double cellSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WEAColors.border.withValues(alpha: .32 * opacity)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.cellSize != cellSize || oldDelegate.opacity != opacity;
}
