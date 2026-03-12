import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'collision_block.dart';
import 'enemy.dart';
import 'health_hud.dart';

class Player extends SpriteAnimationComponent with CollisionCallbacks {
  Player({super.position, required this.joystick})
    : super(size: Vector2(192, 192), anchor: Anchor.center);

  final JoystickComponent joystick;

  // ---------------------------------------------------------------------------
  // Spritesheets
  // ---------------------------------------------------------------------------
  static const String idleAnimationPath =
      'Swordsman_lvl3_Idle_without_shadow.png';
  static const int idleAnimationColumns = 12;

  static const String walkAnimationPath =
      'Swordsman_lvl3_Walk_without_shadow.png';
  static const int walkAnimationColumns = 6;

  static const String runAnimationPath =
      'Swordsman_lvl3_Run_without_shadow.png';
  static const int runAnimationColumns = 8;

  static const String attackAnimationPath =
      'Swordsman_lvl3_attack_without_shadow.png';
  static const int attackAnimationColumns = 8;

  static const String hurtAnimationPath =
      'Swordsman_lvl3_Hurt_without_shadow.png';
  static const int hurtAnimationColumns = 6;

  static const String deathAnimationPath =
      'Swordsman_lvl3_Death_without_shadow.png';
  static const int deathAnimationColumns = 7;

  // ---------------------------------------------------------------------------
  // Constantes
  // ---------------------------------------------------------------------------
  static const int _rows = 4;
  static const double stepTime = 0.2;
  static const double _frameWidth = 64.0;
  static const double _frameHeight = 64.0;
  static const double _walkSpeed = 100.0;
  static const double _runSpeed = 200.0;
  static const double _runThreshold = 0.6;

  // ---------------------------------------------------------------------------
  // Animations
  // ---------------------------------------------------------------------------
  late final List<SpriteAnimation> idleAnimation;
  late final List<SpriteAnimation> walkAnimation;
  late final List<SpriteAnimation> runAnimation;
  late final List<SpriteAnimation> attackAnimation;
  late final List<SpriteAnimation> hurtAnimation;
  late final List<SpriteAnimation> deathAnimation;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  int currentRow = 0;
  bool isMoving = false;
  bool isRunning = false;
  bool isAttacking = false;
  bool isHurt = false;
  bool isDead = false;

  Vector2 _lastPosition = Vector2.zero();

  /// Points de vie
  int maxHealth = 5;
  int health = 5;

  /// Référence vers le HUD (sera assignée par game_world)
  HealthHud? healthHud;

  /// Cooldown pour éviter de prendre des dégâts trop vite
  double _hurtCooldown = 0;
  static const double _hurtCooldownDuration = 1.0; // 1 seconde d'invincibilité

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------
  @override
  Future<void> onLoad() async {
    idleAnimation = [];
    walkAnimation = [];
    runAnimation = [];
    attackAnimation = [];
    hurtAnimation = [];
    deathAnimation = [];

    for (var row = 0; row < _rows; row++) {
      final idleColumns = (row == 3) ? 3 : idleAnimationColumns;

      idleAnimation.add(await _loadRow(
        idleAnimationPath, idleColumns, stepTime, row, true,
      ));
      walkAnimation.add(await _loadRow(
        walkAnimationPath, walkAnimationColumns, stepTime, row, true,
      ));
      runAnimation.add(await _loadRow(
        runAnimationPath, runAnimationColumns, 0.07, row, true,
      ));
      attackAnimation.add(await _loadRow(
        attackAnimationPath, attackAnimationColumns, 0.1, row, false,
      ));
      hurtAnimation.add(await _loadRow(
        hurtAnimationPath, hurtAnimationColumns, 0.1, row, false,
      ));
      deathAnimation.add(await _loadRow(
        deathAnimationPath, deathAnimationColumns, 0.12, row, false,
      ));
    }

    animation = idleAnimation[currentRow];
    playing = true;

    add(
      RectangleHitbox(
        size: Vector2(32, 32),
        position: Vector2(80, 140),
      ),
    );
  }

  /// Charge une animation pour une ligne donnée
  Future<SpriteAnimation> _loadRow(
    String path, int columns, double step, int row, bool loop,
  ) async {
    return SpriteAnimation.load(
      path,
      SpriteAnimationData.sequenced(
        amount: columns,
        stepTime: step,
        textureSize: Vector2(_frameWidth, _frameHeight),
        texturePosition: Vector2(0, row * _frameHeight),
        loop: loop,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dégâts et mort
  // ---------------------------------------------------------------------------

  /// Appelé quand un ennemi touche le joueur
  void takeDamage(int damage) {
    if (isDead) return;
    if (_hurtCooldown > 0) return; // Encore invincible

    health -= damage;
    _hurtCooldown = _hurtCooldownDuration;

    // Met à jour le HUD
    healthHud?.updateHealth(health);

    print('Joueur touché ! PV restants : $health');

    if (health <= 0) {
      _die();
    } else {
      _playHurt();
    }
  }

  void _playHurt() {
    isHurt = true;
    animation = hurtAnimation[currentRow];
    animationTicker!.reset();
    animationTicker!.onComplete = () {
      isHurt = false;
    };
  }

void _die() {
    isDead = true;
    isAttacking = false;
    isHurt = false;
    animation = deathAnimation[currentRow];
    animationTicker!.reset();

    animationTicker!.onComplete = () {
      // Fige l'animation sur la dernière frame (le cadavre au sol)
      animationTicker!.currentIndex = deathAnimation[currentRow].frames.length - 1;
      animationTicker!.update(0); // Force l'affichage de cette frame
      playing = false;

      print('GAME OVER');
    };
  }
  // ---------------------------------------------------------------------------
  // Attaque
  // ---------------------------------------------------------------------------
  void attack() {
    if (isAttacking || isHurt || isDead) return;
    isAttacking = true;

    animation = attackAnimation[currentRow];
    animationTicker!.reset();
    animationTicker!.onComplete = () {
      isAttacking = false;
      animation = isMoving
          ? (isRunning ? runAnimation[currentRow] : walkAnimation[currentRow])
          : idleAnimation[currentRow];
    };
  }

  // ---------------------------------------------------------------------------
  // Mise à jour
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);

    // Réduit le cooldown d'invincibilité
    if (_hurtCooldown > 0) {
      _hurtCooldown -= dt;
    }

    // Pas de mouvement si mort ou blessé
    if (isDead || isHurt) return;

    final input = joystick.relativeDelta;
    final distance = input.length;
    final moving = distance > 0.01;
    final running = distance > _runThreshold;

    if (moving) {
      final speed = running ? _runSpeed : _walkSpeed;
      _lastPosition = position.clone();
      position += input.normalized() * speed * dt;
      currentRow = _rowsFromInput(input);
      isMoving = true;
      isRunning = running;
    } else {
      isMoving = false;
      isRunning = false;
    }

    if (isAttacking) return;

    if (moving) {
      animation = running
          ? runAnimation[currentRow]
          : walkAnimation[currentRow];
    } else {
      animation = idleAnimation[currentRow];
    }
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------
  @override
@override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is CollisionBlock) {
      position = _lastPosition;
    }

    // Le joueur attaque un ennemi → dégâts à l'ennemi
    if (other is Enemy && isAttacking) {
      other.takeDamage(1);
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaire
  // ---------------------------------------------------------------------------
  int _rowsFromInput(Vector2 input) {
    if (input.x.abs() > input.y.abs()) {
      return input.x > 0 ? 2 : 1;
    } else {
      return input.y > 0 ? 0 : 3;
    }
  }
}