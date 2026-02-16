import 'dart:ui';

import 'package:flame/components.dart';

class AttackRangeEffectComponent extends PositionComponent {
  final double radius;
  final double duration;
  final Color color;

  double _elapsed = 0;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  AttackRangeEffectComponent({
    required Vector2 center,
    required this.radius,
    required this.color,
    this.duration = 0.14,
  }) : super(
         position: center,
         anchor: Anchor.center,
         size: Vector2.all(radius * 2),
         priority: 40,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    final alpha = 1.0 - progress;
    final pulse = 0.86 + (progress * 0.34);
    final r = radius * pulse;

    _fillPaint.color = _withOpacity(color, 0.12 * alpha);
    _strokePaint
      ..color = _withOpacity(color, 0.9 * alpha)
      ..strokeWidth = 2.0 + (alpha * 2.0);

    canvas.drawCircle(Offset.zero, r, _fillPaint);
    canvas.drawCircle(Offset.zero, r, _strokePaint);
  }

  Color _withOpacity(Color c, double opacity) {
    return c.withValues(alpha: opacity.clamp(0.0, 1.0));
  }
}
