import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'collision_block.dart';

/// Directions d'animation partagées entre Player et Enemy.
/// Chaque spritesheet peut avoir un ordre de lignes différent :
/// utiliser [DirectionMap] pour configurer le mapping.
enum Direction { down, left, right, up }

/// Associe chaque [Direction] à un index de ligne dans la spritesheet.
class DirectionMap {
  const DirectionMap({
    required this.down,
    required this.left,
    required this.right,
    required this.up,
  });

  final int down;
  final int left;
  final int right;
  final int up;

  int fromVector(Vector2 dir) {
    if (dir.x.abs() > dir.y.abs()) {
      return dir.x > 0 ? right : left;
    } else {
      return dir.y > 0 ? down : up;
    }
  }
}

/// Mixin partagé entre Player et Enemy pour le chargement d'animations
/// et la gestion des collisions avec les blocs.
mixin CharacterMixin on SpriteAnimationComponent, CollisionCallbacks {
  static const int defaultRows = 4;
  static const double defaultFrameWidth = 64.0;
  static const double defaultFrameHeight = 64.0;

  Vector2 lastPosition = Vector2.zero();

  /// Charge une seule animation (une ligne de spritesheet).
  Future<SpriteAnimation> loadAnimationRow({
    required String path,
    required int columns,
    required double stepTime,
    required int row,
    required bool loop,
    double frameWidth = defaultFrameWidth,
    double frameHeight = defaultFrameHeight,
  }) async {
    return SpriteAnimation.load(
      path,
      SpriteAnimationData.sequenced(
        amount: columns,
        stepTime: stepTime,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, row * frameHeight),
        loop: loop,
      ),
    );
  }

  /// Charge toutes les lignes d'une spritesheet (une animation par direction).
  Future<List<SpriteAnimation>> loadAllRows({
    required String path,
    required int columns,
    required double stepTime,
    required bool loop,
    int rows = defaultRows,
    double frameWidth = defaultFrameWidth,
    double frameHeight = defaultFrameHeight,
    Map<int, int>? columnOverrides,
  }) async {
    final anims = <SpriteAnimation>[];
    for (var row = 0; row < rows; row++) {
      final cols = columnOverrides?[row] ?? columns;
      anims.add(await loadAnimationRow(
        path: path,
        columns: cols,
        stepTime: stepTime,
        row: row,
        loop: loop,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      ));
    }
    return anims;
  }

  /// Gère la collision avec un [CollisionBlock] en revenant à la position
  /// précédente.
  void handleBlockCollision(PositionComponent other) {
    if (other is CollisionBlock) {
      position = lastPosition;
    }
  }
}
