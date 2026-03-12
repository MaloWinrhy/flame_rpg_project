import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'character.dart';
import 'enemy_health_bar.dart';
import 'player.dart';

/// Les différents états du monstre.
enum EnemyState { idle, patrol, chase, attack, hurt, dead }

class Enemy extends SpriteAnimationComponent
    with CollisionCallbacks, CharacterMixin {
  Enemy({required Vector2 position, required this.player})
    : super(
        position: position,
        size: Vector2(200, 200),
        anchor: Anchor.center,
      );

  final Player player;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  static const double _patrolSpeed = 50.0;
  static const double _chaseSpeed = 100.0;
  static const double _detectionRange = 250.0;
  static const double _patrolDistance = 150.0;
  static const double _attackRange = 60.0;
  static const double _attackDamageRange = 100.0;
  static const double _attackCooldownDuration = 1.5;

  static const Vector2 _hitboxSize = Vector2(40, 40);
  static const Vector2 _hitboxOffset = Vector2(44, 70);

  /// Mapping des directions pour la spritesheet de l'orc.
  /// Lignes : 0=bas, 1=haut, 2=gauche, 3=droite
  static const DirectionMap _dirMap = DirectionMap(
    down: 0, up: 1, left: 2, right: 3,
  );

  double _attackCooldown = 0;

  // ---------------------------------------------------------------------------
  // Spritesheets
  // ---------------------------------------------------------------------------
  static const String _idlePath = 'orc1_idle_without_shadow.png';
  static const int _idleColumns = 4;

  static const String _walkPath = 'orc1_walk_without_shadow.png';
  static const int _walkColumns = 6;

  static const String _runPath = 'orc1_run_without_shadow.png';
  static const int _runColumns = 8;

  static const String _attackPath = 'orc1_attack_without_shadow.png';
  static const int _attackColumns = 8;

  static const String _hurtPath = 'orc1_hurt_without_shadow.png';
  static const int _hurtColumns = 6;

  static const String _deathPath = 'orc1_death_without_shadow.png';
  static const int _deathColumns = 8;

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
  EnemyState _state = EnemyState.patrol;
  int _currentRow = 0;
  int _patrolDirection = 1;
  late final Vector2 _startPosition;
  bool _isAttacking = false;
  bool _isHurt = false;

  int _maxHealth = 3;
  int health = 3;
  late final EnemyHealthBar _healthBar;

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------
  @override
  Future<void> onLoad() async {
    _startPosition = position.clone();

    try {
      _idleAnim = await loadAllRows(
        path: _idlePath, columns: _idleColumns, stepTime: 0.25, loop: true,
      );
      _walkAnim = await loadAllRows(
        path: _walkPath, columns: _walkColumns, stepTime: 0.15, loop: true,
      );
      _runAnim = await loadAllRows(
        path: _runPath, columns: _runColumns, stepTime: 0.1, loop: true,
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
      throw StateError('Impossible de charger les sprites de l\'ennemi : $e');
    }

    animation = _idleAnim[0];
    playing = true;

    add(RectangleHitbox(size: _hitboxSize, position: _hitboxOffset));

    // Barre de vie au-dessus de l'ennemi
    _healthBar = EnemyHealthBar(maxHealth: _maxHealth, parentSize: size);
    add(_healthBar);
  }

  // ---------------------------------------------------------------------------
  // Mise à jour
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);

    if (_state == EnemyState.dead) return;
    if (_isAttacking || _isHurt) return;

    if (_attackCooldown > 0) _attackCooldown -= dt;

    final distanceToPlayer = position.distanceTo(player.position);

    if (distanceToPlayer < _attackRange && _attackCooldown <= 0) {
      _state = EnemyState.attack;
    } else if (distanceToPlayer < _attackRange) {
      _state = EnemyState.idle;
    } else if (distanceToPlayer < _detectionRange) {
      _state = EnemyState.chase;
    } else {
      _state = EnemyState.patrol;
    }

    lastPosition = position.clone();

    switch (_state) {
      case EnemyState.idle:
        animation = _idleAnim[_currentRow];
        break;
      case EnemyState.patrol:
        _patrol(dt);
        break;
      case EnemyState.chase:
        _chase(dt);
        break;
      case EnemyState.attack:
        _doAttack();
        break;
      case EnemyState.hurt:
      case EnemyState.dead:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Comportements
  // ---------------------------------------------------------------------------
  void _patrol(double dt) {
    position.x += _patrolDirection * _patrolSpeed * dt;

    if ((position.x - _startPosition.x).abs() > _patrolDistance) {
      _patrolDirection *= -1;
    }

    _currentRow = _patrolDirection > 0 ? _dirMap.right : _dirMap.left;
    animation = _walkAnim[_currentRow];
  }

  void _chase(double dt) {
    final direction = (player.position - position).normalized();
    position += direction * _chaseSpeed * dt;
    _currentRow = _dirMap.fromVector(direction);
    animation = _runAnim[_currentRow];
  }

  void _doAttack() {
    _isAttacking = true;
    _attackCooldown = _attackCooldownDuration;

    final direction = (player.position - position).normalized();
    _currentRow = _dirMap.fromVector(direction);

    animation = _attackAnim[_currentRow];
    animationTicker!.reset();

    bool hasDamaged = false;

    animationTicker!.onFrame = (frameIndex) {
      if (frameIndex == 4 && !hasDamaged) {
        hasDamaged = true;
        if (position.distanceTo(player.position) < _attackDamageRange) {
          player.takeDamage(1);
        }
      }
    };

    animationTicker!.onComplete = () {
      _isAttacking = false;
    };
  }

  // ---------------------------------------------------------------------------
  // Dégâts et mort
  // ---------------------------------------------------------------------------
  void takeDamage(int damage) {
    if (_state == EnemyState.dead) return;

    health -= damage;
    _healthBar.updateHealth(health);

    if (health <= 0) {
      _die();
    } else {
      _isHurt = true;
      animation = _hurtAnim[_currentRow];
      animationTicker!.reset();
      animationTicker!.onComplete = () {
        _isHurt = false;
      };
    }
  }

  void _die() {
    _state = EnemyState.dead;
    _isAttacking = true;
    animation = _deathAnim[_currentRow];
    animationTicker!.reset();

    animationTicker!.onComplete = () {
      removeFromParent();
    };
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    handleBlockCollision(other);
  }
}
