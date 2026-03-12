import 'dart:ui';

import 'package:flame/components.dart';

/// Petite barre de vie affichée au-dessus d'un ennemi.
///
/// Se positionne comme enfant du composant ennemi et se dessine
/// relativement à son parent.
class EnemyHealthBar extends PositionComponent {
  EnemyHealthBar({
    required this.maxHealth,
    required Vector2 parentSize,
  }) : currentHealth = maxHealth,
       super(
         position: Vector2(parentSize.x / 2 - _barWidth / 2, -4),
         size: Vector2(_barWidth, _barHeight),
       );

  final int maxHealth;
  int currentHealth;

  static const double _barWidth = 48.0;
  static const double _barHeight = 6.0;

  final Paint _bgPaint = Paint()..color = const Color(0x88000000);
  final Paint _healthPaint = Paint()..color = const Color(0xFFFF3333);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF660000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  void updateHealth(int health) {
    currentHealth = health.clamp(0, maxHealth);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final fullRect = Rect.fromLTWH(0, 0, _barWidth, _barHeight);

    // Fond
    canvas.drawRect(fullRect, _bgPaint);

    // Barre de vie proportionnelle
    final healthRatio = currentHealth / maxHealth;
    final healthRect = Rect.fromLTWH(0, 0, _barWidth * healthRatio, _barHeight);
    canvas.drawRect(healthRect, _healthPaint);

    // Bordure
    canvas.drawRect(fullRect, _borderPaint);
  }
}
