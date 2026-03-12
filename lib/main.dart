import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game_world.dart';

void main() {
  runApp(
    GameWidget(
      game: FlameGame(world: MyWorld()),
    ),
  );
}