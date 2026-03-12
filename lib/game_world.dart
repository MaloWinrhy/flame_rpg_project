import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/widgets.dart';

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
        paint: Paint()..color = const Color(0xCCFFFFFF), // Blanc semi-transparent
      ),
      // Le "background" est le grand cercle fixe qui délimite la zone du joystick
      background: CircleComponent(
        radius: 64,
        paint: Paint()..color = const Color(0x66FFFFFF), // Blanc plus transparent
      ),
      // Position du joystick : en bas à gauche de l'écran
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    )..priority = 100; // Priorité élevée → affiché au-dessus des autres éléments

    // On ajoute le joystick au viewport de la caméra (= le HUD).
    // Cela garantit qu'il reste fixe à l'écran même quand la caméra bouge.
    findGame()!.camera.viewport.add(joystick);

    final map = await TiledComponent.load(
      'Dungeon1.tmx',
      Vector2.all(64),
    );
    add(map);


    // -------------------------------------------------------------------------
    // Création du joueur au centre du monde (position 0, 0)
    // On lui passe le joystick pour qu'il puisse lire les entrées
    // -------------------------------------------------------------------------
    final player = Player(position: Vector2.zero(), joystick: joystick);

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