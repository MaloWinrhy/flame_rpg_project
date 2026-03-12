

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

///Fonctionnement :
///Créer un composant retangulaire de 64x64
///Qui possede une hitbox de 64x64 et permet au moteur de collision de flutter flame 
///de détecté le chevauchement d'une autre hitbox

class CollisionBlock extends PositionComponent with CollisionCallbacks
{
  CollisionBlock({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    /// on va rajouter une hitbox qui couvre un bloc
    /// c'est ce composant qui va permettre au moteur 
    /// de flame de gérer les collisions
    add(RectangleHitbox());
  }

}