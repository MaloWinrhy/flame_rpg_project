import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'character.dart';
import 'enemy.dart';
import 'health_hud.dart';

class Player extends SpriteAnimationComponent
    with CollisionCallbacks, CharacterMixin {
  Player({super.position, required this.joystick})
    : super(size: Vector2(192, 192), anchor: Anchor.center);

  final JoystickComponent joystick;

  // ---------------------------------------------------------------------------
  // Spritesheets
  // ---------------------------------------------------------------------------
  static const String _idlePath = 'Swordsman_lvl3_Idle_without_shadow.png';
  static const int _idleColumns = 12;

  static const String _walkPath = 'Swordsman_lvl3_Walk_without_shadow.png';
  static const int _walkColumns = 6;

  static const String _runPath = 'Swordsman_lvl3_Run_without_shadow.png';
  static const int _runColumns = 8;

  static const String _attackPath = 'Swordsman_lvl3_attack_without_shadow.png';
  static const int _attackColumns = 8;

  static const String _hurtPath = 'Swordsman_lvl3_Hurt_without_shadow.png';
  static const int _hurtColumns = 6;

  static const String _deathPath = 'Swordsman_lvl3_Death_without_shadow.png';
  static const int _deathColumns = 7;

  // ---------------------------------------------------------------------------
  // Constantes
  // ---------------------------------------------------------------------------
  static const double _stepTime = 0.2;
  static const double _walkSpeed = 100.0;
  static const double _runSpeed = 200.0;
  static const double _runThreshold = 0.6;

  static const Vector2 _hitboxSize = Vector2(32, 32);
  static const Vector2 _hitboxOffset = Vector2(80, 140);

  /// Mapping des directions pour la spritesheet du joueur.
  /// Lignes : 0=bas, 1=gauche, 2=droite, 3=haut
  static const DirectionMap _dirMap = DirectionMap(
    down: 0, left: 1, right: 2, up: 3,
  );

  // ---------------------------------------------------------------------------
  // Animations
  // ---------------------------------------------------------------------------
  late final List<SpriteAnimation> _idleAnim;
  late final List<SpriteAnimation> _walkAnim;
  late final List<SpriteAnimation> _runAnim;
  late final List<SpriteAnimation> _attackAnim;
  late final List<SpriteAnimation> _hurtAnim;
  late final List<SpriteAnimation> _deathAnim;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  int _currentRow = 0;
  bool _isMoving = false;
  bool _isRunning = false;
  bool isAttacking = false;
  bool _isHurt = false;
  bool isDead = false;
  bool _hasDealtDamageThisAttack = false;

  /// Points de vie
  int maxHealth = 5;
  int health = 5;

  /// Référence vers le HUD (sera assignée par game_world)
  HealthHud? healthHud;

  /// Cooldown pour éviter de prendre des dégâts trop vite
  double _hurtCooldown = 0;
  static const double _hurtCooldownDuration = 1.0;

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------
  @override
  Future<void> onLoad() async {
    try {
      _idleAnim = await loadAllRows(
        path: _idlePath, columns: _idleColumns, stepTime: _stepTime, loop: true,
        columnOverrides: {3: 3},
      );
      _walkAnim = await loadAllRows(
        path: _walkPath, columns: _walkColumns, stepTime: _stepTime, loop: true,
      );
      _runAnim = await loadAllRows(
        path: _runPath, columns: _runColumns, stepTime: 0.07, loop: true,
      );
      _attackAnim = await loadAllRows(
        path: _attackPath, columns: _attackColumns, stepTime: 0.1, loop: false,
      );
      _hurtAnim = await loadAllRows(
        path: _hurtPath, columns: _hurtColumns, stepTime: 0.1, loop: false,
      );
      _deathAnim = await loadAllRows(
        path: _deathPath, columns: _deathColumns, stepTime: 0.12, loop: false,
      );
    } catch (e) {
      throw StateError('Impossible de charger les sprites du joueur : $e');
    }

    animation = _idleAnim[_currentRow];
    playing = true;

    add(RectangleHitbox(size: _hitboxSize, position: _hitboxOffset));
  }

  // ---------------------------------------------------------------------------
  // Dégâts et mort
  // ---------------------------------------------------------------------------
  void takeDamage(int damage) {
    if (isDead || _hurtCooldown > 0) return;

    health -= damage;
    _hurtCooldown = _hurtCooldownDuration;
    healthHud?.updateHealth(health);

    if (health <= 0) {
      _die();
    } else {
      _playHurt();
    }
  }

  void _playHurt() {
    _isHurt = true;
    animation = _hurtAnim[_currentRow];
    animationTicker!.reset();
    animationTicker!.onComplete = () {
      _isHurt = false;
    };
  }

  void _die() {
    isDead = true;
    isAttacking = false;
    _isHurt = false;
    animation = _deathAnim[_currentRow];
    animationTicker!.reset();

    animationTicker!.onComplete = () {
      animationTicker!.currentIndex =
          _deathAnim[_currentRow].frames.length - 1;
      animationTicker!.update(0);
      playing = false;
      // TODO: afficher un écran de Game Over
    };
  }

  // ---------------------------------------------------------------------------
  // Attaque
  // ---------------------------------------------------------------------------
  void attack() {
    if (isAttacking || _isHurt || isDead) return;
    isAttacking = true;
    _hasDealtDamageThisAttack = false;

    animation = _attackAnim[_currentRow];
    animationTicker!.reset();
    animationTicker!.onComplete = () {
      isAttacking = false;
      animation = _isMoving
          ? (_isRunning ? _runAnim[_currentRow] : _walkAnim[_currentRow])
          : _idleAnim[_currentRow];
    };
  }

  // ---------------------------------------------------------------------------
  // Mise à jour
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);

    if (_hurtCooldown > 0) _hurtCooldown -= dt;
    if (isDead || _isHurt) return;

    final input = joystick.relativeDelta;
    final distance = input.length;
    final moving = distance > 0.01;
    final running = distance > _runThreshold;

    if (moving) {
      final speed = running ? _runSpeed : _walkSpeed;
      lastPosition = position.clone();
      position += input.normalized() * speed * dt;
      _currentRow = _dirMap.fromVector(input);
      _isMoving = true;
      _isRunning = running;
    } else {
      _isMoving = false;
      _isRunning = false;
    }

    if (isAttacking) return;

    if (moving) {
      animation = running ? _runAnim[_currentRow] : _walkAnim[_currentRow];
    } else {
      animation = _idleAnim[_currentRow];
    }
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    handleBlockCollision(other);

    if (other is Enemy && isAttacking && !_hasDealtDamageThisAttack) {
      other.takeDamage(1);
      _hasDealtDamageThisAttack = true;
    }
  }
}
