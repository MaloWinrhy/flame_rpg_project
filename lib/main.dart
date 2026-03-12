import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game_world.dart';

class MyGame extends FlameGame {
  MyGame() : super(world: MyWorld());

   
  @override
  bool get debugMode => false;
}
void main() {
  runApp(
    
    GameWidget(
      
      game: MyGame()
    ),
  );
}