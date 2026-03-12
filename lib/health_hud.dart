import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

/// Affiche les cœurs de vie en haut de l'écran.
///
/// Chaque cœur est un petit carré :
///   - Rouge = point de vie restant
///   - Gris  = point de vie perdu
class HealthHud extends PositionComponent {
  HealthHud({required this.maxHealth})
    : currentHealth = maxHealth,
      super(
        position: Vector2(40, 60),
        anchor: Anchor.topLeft,
      );

  final int maxHealth;
  int currentHealth;

  /// Taille d'un cœur et espacement
  static const double _heartSize = 32.0;
  static const double _spacing = 8.0;

  /// Couleurs
  final Paint _fullPaint = Paint()..color = const Color(0xFFFF3333);
  final Paint _emptyPaint = Paint()..color = const Color(0x66FFFFFF);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF990000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// Met à jour le nombre de cœurs affichés
  void updateHealth(int health) {
    currentHealth = health.clamp(0, maxHealth);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (var i = 0; i < maxHealth; i++) {
      final x = i * (_heartSize + _spacing);
      final rect = Rect.fromLTWH(x, 0, _heartSize, _heartSize);

      // Dessine un cœur plein ou vide
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        i < currentHealth ? _fullPaint : _emptyPaint,
      );

      // Bordure
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        _borderPaint,
      );

      // Dessin simplifié d'un cœur (texte ♥)
      final textPainter = TextPainter(
        text: TextSpan(
          text: '♥',
          style: TextStyle(
            fontSize: 22,
            color: i < currentHealth
                ? const Color(0xFFFFFFFF)
                : const Color(0x44FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (_heartSize - textPainter.width) / 2,
               (_heartSize - textPainter.height) / 2),
      );
    }
  }
}