import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/widgets.dart';
import 'package:game/collision_block.dart';
import 'package:game/enemy.dart';
import 'package:game/health_hud.dart';

import 'player.dart';

/// Classe représentant le monde du jeu.
/// [World] est le conteneur principal de Flame qui héberge
/// tous les éléments visibles (joueur, ennemis, décors, etc.).
class MyWorld extends World {
  /// Référence vers le joystick virtuel, utilisé pour contrôler le joueur.
  late final JoystickComponent joystick;

  @override
  Future<void> onLoad() async {
    // -------------------------------------------------------------------------
    // Création du joystick virtuel (stick analogique à l'écran)
    // -------------------------------------------------------------------------
    joystick = JoystickComponent(
      // Le "knob" est le petit cercle central que le joueur déplace avec le doigt
      knob: CircleComponent(
        radius: 28,
        paint: Paint()
          ..color = const Color(0xCCFFFFFF), // Blanc semi-transparent
      ),
      // Le "background" est le grand cercle fixe qui délimite la zone du joystick
      background: CircleComponent(
        radius: 64,
        paint: Paint()
          ..color = const Color(0x66FFFFFF), // Blanc plus transparent
      ),
      // Position du joystick : en bas à gauche de l'écran
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    )..priority = 100; // Priorité élevée → affiché au-dessus des autres éléments

    // On ajoute le joystick au viewport de la caméra (= le HUD).
    // Cela garantit qu'il reste fixe à l'écran même quand la caméra bouge.
    findGame()!.camera.viewport.add(joystick);

    final map = await TiledComponent.load('Dungeon1.tmx', Vector2.all(64));
    add(map);

    for (final layer in map.tileMap.map.layers) {
      print('Layer trouvée : "${layer.name}" (type: ${layer.type})');
    }
    // ---------------------------------------------------------------------------
    // Charge les colisions depuis la map
    // ---------------------------------------------------------------------------

  const tileDisplaySize = 64.0;
    const tileRealSize = 16.0;
    const scale = tileDisplaySize / tileRealSize;

    final collisionLayer = map.tileMap.getLayer<ObjectGroup>('Collisions');
    if (collisionLayer != null) {
      int count = 0;
      for (final obj in collisionLayer.objects) {
        // Ignore les objets de taille 0 (points)
        if (obj.width > 0 && obj.height > 0) {
          add(
            CollisionBlock(
              position: Vector2(obj.x * scale, obj.y * scale),
              size: Vector2(obj.width * scale, obj.height * scale),
            ),
          );
          count++;
        }
      }
    } else {
    }

    // -------------------------------------------------------------------------
    // Joueur AU CENTRE de la carte (pas à 0,0)
    // -------------------------------------------------------------------------
    final mapWidth = map.tileMap.map.width * tileDisplaySize;
    final mapHeight = map.tileMap.map.height * tileDisplaySize;
    print('Taille carte : $mapWidth x $mapHeight');

    final player = Player(
      position: Vector2(mapWidth / 2, mapHeight / 2),
      joystick: joystick,
    );

        // -------------------------------------------------------------------------
    // Ennemy AU CENTRE de la carte (pas à 0,0)
    // -------------------------------------------------------------------------

      // -------------------------------------------------------------------------
    // HUD : cœurs de vie en haut de l'écran
    // -------------------------------------------------------------------------
    final healthHud = HealthHud(maxHealth: player.maxHealth);
    healthHud.priority = 100;
    findGame()!.camera.viewport.add(healthHud);

    // Lie le HUD au joueur pour que les dégâts mettent à jour l'affichage
    player.healthHud = healthHud;

    // -------------------------------------------------------------------------
    // Ennemi
    // -------------------------------------------------------------------------

    final enemy = Enemy(
      position: Vector2(mapWidth / 2 + 200, mapHeight / 2),
      player: player,
    );
    add(enemy);
    // -------------------------------------------------------------------------
    // Création du bouton d'attaque (cercle rouge en bas à droite)
    // -------------------------------------------------------------------------
    final attackButton = HudButtonComponent(
      button: CircleComponent(
        radius: 40,
        paint: Paint()..color = const Color(0xCCFF4444),
      ),
      margin: const EdgeInsets.only(right: 32, bottom: 50),
      onPressed: () => player.attack(),
    )..priority = 100;

    // Ajout du bouton d'attaque au viewport (HUD fixe à l'écran)
    findGame()!.camera.viewport.add(attackButton);

    // -------------------------------------------------------------------------
    // Ajout du joueur au monde et suivi par la caméra
    // -------------------------------------------------------------------------

    // add() ajoute le joueur comme enfant du World → il sera affiché et mis à jour
    add(player);

    // La caméra suit le joueur : le personnage reste toujours au centre de l'écran,
    // et c'est le monde autour qui "défile"
    findGame()!.camera.follow(player);
  }
}
