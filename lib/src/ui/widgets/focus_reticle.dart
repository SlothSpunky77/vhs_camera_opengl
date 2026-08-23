import 'package:flutter/material.dart';

import '../vhs_theme.dart';

/// The manual-focus reticle drawn where the user tapped.
///
/// It lives outside the recorded [RepaintBoundary] so it never gets burnt into
/// a photo or a tape.
class FocusReticle extends StatefulWidget {
  const FocusReticle({required this.position, super.key});

  final Offset position;

  @override
  State<FocusReticle> createState() => _FocusReticleState();
}

class _FocusReticleState extends State<FocusReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double box = 78;
    return Positioned(
      left: widget.position.dx - box / 2,
      top: widget.position.dy - box / 2,
      child: IgnorePointer(
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.5, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          ),
          child: SizedBox(
            width: box,
            height: box,
            child: CustomPaint(painter: _ReticlePainter()),
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = VhsTheme.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final double arm = size.width * 0.28;
    final Rect r = Offset.zero & size;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(arm * dx, 0), paint);
      canvas.drawLine(origin, origin.translate(0, arm * dy), paint);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);

    canvas.drawLine(
      Offset(r.center.dx, r.center.dy - 6),
      Offset(r.center.dx, r.center.dy + 6),
      paint,
    );
    canvas.drawLine(
      Offset(r.center.dx - 6, r.center.dy),
      Offset(r.center.dx + 6, r.center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => false;
}
