import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'collision_block.dart';
import 'player.dart';

/// Les différents états du monstre.
///   - idle : ne bouge pas
///   - patrol : va et vient entre deux points
///   - chase : poursuit le joueur
///   - attack : attaque le joueur (au contact)
///   - hurt : vient de recevoir un coup
///   - dead : mort, à supprimer
enum EnemyState { idle, patrol, chase, attack, hurt, dead }

class Enemy extends SpriteAnimationComponent with CollisionCallbacks {
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
  static const double _detectionRange = 250.0;  // Distance de détection
  static const double _patrolDistance = 150.0;    // Distance de patrouille

  static const int _rows = 4;
  static const double _frameWidth = 64.0;
  static const double _frameHeight = 64.0;

  // Augmentez le range d'attaque pour qu'il attaque moins loin
  static const double _attackRange = 60.0;
  static const double _attackDamageRange = 100.0; // Portée réelle des dégâts

  // Hitbox
  static const Vector2 _hitboxSize = Vector2(40, 40);
  static const Vector2 _hitboxOffset = Vector2(44, 70);

  // Ajoutez un cooldown d'attaque pour qu'il n'attaque pas en boucle
  double _attackCooldown = 0;
  static const double _attackCooldownDuration = 1.5; // secondes entre 2 attaques

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
  // Animations (une par direction, index 0=bas 1=gauche 2=droite 3=haut)
  // ---------------------------------------------------------------------------
  late final List<SpriteAnimation> idleAnim;
  late final List<SpriteAnimation> walkAnim;
  late final List<SpriteAnimation> runAnim;
  late final List<SpriteAnimation> attackAnim;
  late final List<SpriteAnimation> hurtAnim;
  late final List<SpriteAnimation> deathAnim;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  EnemyState _state = EnemyState.patrol;
  int _currentRow = 0;           // Direction actuelle
  int _patrolDirection = 1;      // 1 = droite, -1 = gauche
  late final Vector2 _startPosition;
  Vector2 _lastPosition = Vector2.zero();
  bool _isAttacking = false;
  bool _isHurt = false;

  /// Points de vie du monstre
  int health = 3;

  @override
  Future<void> onLoad() async {
    _startPosition = position.clone();

    // Charge toutes les animations
    idleAnim = await _loadAnim(_idlePath, _idleColumns, 0.25, true);
    walkAnim = await _loadAnim(_walkPath, _walkColumns, 0.15, true);
    runAnim = await _loadAnim(_runPath, _runColumns, 0.1, true);
    attackAnim = await _loadAnim(_attackPath, _attackColumns, 0.1, false);
    hurtAnim = await _loadAnim(_hurtPath, _hurtColumns, 0.1, false);
    deathAnim = await _loadAnim(_deathPath, _deathColumns, 0.12, false);

    animation = idleAnim[0];
    playing = true;

    // Hitbox du monstre
    add(
      RectangleHitbox(
        size: _hitboxSize,
        position: _hitboxOffset,
      ),
    );
  }

  /// Charge une liste de 4 animations (une par direction)
  Future<List<SpriteAnimation>> _loadAnim(
    String path,
    int columns,
    double stepTime,
    bool loop,
  ) async {
    final anims = <SpriteAnimation>[];
    for (var row = 0; row < _rows; row++) {
      anims.add(
        await SpriteAnimation.load(
          path,
          SpriteAnimationData.sequenced(
            amount: columns,
            stepTime: stepTime,
            textureSize: Vector2(_frameWidth, _frameHeight),
            texturePosition: Vector2(0, row * _frameHeight),
            loop: loop,
          ),
        ),
      );
    }
    return anims;
  }

  // ---------------------------------------------------------------------------
  // Mise à jour
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);

    if (_state == EnemyState.dead) return;
    if (_isAttacking || _isHurt) return;

    // Réduit le cooldown d'attaque
    if (_attackCooldown > 0) {
      _attackCooldown -= dt;
    }

    final distanceToPlayer = position.distanceTo(player.position);

    if (distanceToPlayer < _attackRange && _attackCooldown <= 0) {
      _state = EnemyState.attack;
    } else if (distanceToPlayer < _attackRange && _attackCooldown > 0) {
      // À portée mais en cooldown → reste sur place et attend
      _state = EnemyState.idle;
    } else if (distanceToPlayer < _detectionRange) {
      _state = EnemyState.chase;
    } else {
      _state = EnemyState.patrol;
    }

    _lastPosition = position.clone();

    switch (_state) {
      case EnemyState.idle:
        animation = idleAnim[_currentRow];
        break;
      case EnemyState.patrol:
        _patrol(dt);
        break;
      case EnemyState.chase:
        _chase(dt);
        break;
      case EnemyState.attack:
        _attack();
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

    _currentRow = _patrolDirection > 0 ? 2 : 1;
    animation = walkAnim[_currentRow];
  }

  void _chase(double dt) {
    final direction = (player.position - position).normalized();
    position += direction * _chaseSpeed * dt;

    // Choisit la direction selon l'axe dominant
    _currentRow = _rowFromDirection(direction);
    animation = runAnim[_currentRow];
  }

  void _attack() {
    _isAttacking = true;
    _attackCooldown = _attackCooldownDuration;

    // Tourne vers le joueur avant d'attaquer
    final direction = (player.position - position).normalized();
    _currentRow = _rowFromDirection(direction);

    animation = attackAnim[_currentRow];
    animationTicker!.reset();

    // Inflige les dégâts à mi-animation (pas à la fin)
    bool hasDamaged = false;

    animationTicker!.onFrame = (frameIndex) {
      // Frame 4 sur 8 = milieu de l'animation d'attaque
      if (frameIndex == 4 && !hasDamaged) {
        hasDamaged = true;
        final dist = position.distanceTo(player.position);
        if (dist < _attackDamageRange) {
          player.takeDamage(1);
        }
      }
    };

    animationTicker!.onComplete = () {
      _isAttacking = false;
      hasDamaged = false;
    };
  }
  // ---------------------------------------------------------------------------
  // Dégâts et mort
  // ---------------------------------------------------------------------------

  /// Appelé quand le joueur frappe le monstre
  void takeDamage(int damage) {
    if (_state == EnemyState.dead) return;

    health -= damage;
    if (health <= 0) {
      _die();
    } else {
      _isHurt = true;
      animation = hurtAnim[_currentRow];
      animationTicker!.reset();
      animationTicker!.onComplete = () {
        _isHurt = false;
      };
    }
  }

  void _die() {
    _state = EnemyState.dead;
    _isAttacking = true;
    animation = deathAnim[_currentRow];
    animationTicker!.reset();

    animationTicker!.onComplete = () {
      // Supprime le monstre du jeu après l'animation de mort
      removeFromParent();
    };
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is CollisionBlock) {
      position = _lastPosition;
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaire
  // ---------------------------------------------------------------------------

  int _rowFromDirection(Vector2 dir) {
    if (dir.x.abs() > dir.y.abs()) {
      return dir.x > 0 ? 3 : 2;  // Droite ou Gauche
    } else {
      return dir.y > 0 ? 0 : 1;  // Bas ou Haut
    }
  }
}