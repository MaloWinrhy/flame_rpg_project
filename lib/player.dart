import 'package:flame/components.dart';
import 'package:game/collision_block.dart';
import 'package:flame/collisions.dart'; 

/// Classe représentant le joueur (un épéiste niveau 3).
/// Elle hérite de [SpriteAnimationComponent] pour gérer
/// l'affichage et l'animation du sprite à l'écran.
class Player extends SpriteAnimationComponent with CollisionCallbacks {
  /// Constructeur : reçoit une position et un joystick.
  /// Le sprite fait 192x192 pixels à l'écran, ancré au centre.
  Player({super.position, required this.joystick})
    : super(size: Vector2(192, 192), anchor: Anchor.center);

  /// Référence vers le joystick virtuel qui contrôle le personnage.
  final JoystickComponent joystick;

  // ---------------------------------------------------------------------------
  // Chemins vers les spritesheets et nombre de colonnes (frames) par animation.
  // Chaque spritesheet contient plusieurs lignes (directions) et colonnes (frames).
  // ---------------------------------------------------------------------------

  static const String idleAnimationPath =
      'Swordsman_lvl3_Idle_without_shadow.png';
  static const int idleAnimationColumns = 12; // 12 frames pour l'idle

  static const String walkAnimationPath =
      'Swordsman_lvl3_Walk_without_shadow.png';
  static const int walkAnimationColumns = 6; // 6 frames pour la marche

  static const String runAnimationPath =
      'Swordsman_lvl3_Run_without_shadow.png';
  static const int runAnimationColumns = 8; // 8 frames pour la course

  static const String attackAnimationPath =
      'Swordsman_lvl3_attack_without_shadow.png';
  static const int attackAnimationColumns = 8; // 8 frames pour l'attaque

  // ---------------------------------------------------------------------------
  // Constantes de configuration
  // ---------------------------------------------------------------------------

  /// Nombre de lignes dans chaque spritesheet.
  /// Chaque ligne correspond à une direction :
  ///   0 = bas, 1 = gauche, 2 = droite, 3 = haut
  static const int _rows = 4;

  /// Durée d'affichage de chaque frame (en secondes).
  static const double stepTime = 0.2;

  /// Dimensions d'une frame individuelle dans le spritesheet (en pixels).
  static const double _frameWidth = 64.0;
  static const double _frameHeight = 64.0;

  /// Vitesses de déplacement (en pixels par seconde).
  static const double _walkSpeed = 100.0;
  static const double _runSpeed = 200.0;

  /// Seuil du joystick au-delà duquel le personnage court
  /// (valeur entre 0 et 1, où 1 = joystick poussé à fond).
  static const double _runThreshold = 0.6;

  // ---------------------------------------------------------------------------
  // Listes d'animations : une animation par direction (index = ligne du sprite)
  // ---------------------------------------------------------------------------

  late final List<SpriteAnimation> idleAnimation; // Repos
  late final List<SpriteAnimation> walkAnimation; // Marche
  late final List<SpriteAnimation> runAnimation; // Course
  late final List<SpriteAnimation> attackAnimation; // Attaque

  /// Direction actuelle du joueur (index de la ligne du spritesheet).
  int currentRow = 0;

  /// Drapeaux d'état du personnage.
  bool isMoving = false;
  bool isRunning = false;
  bool isAttacking = false;

  //Collision
  Vector2 _lastPosition = Vector2.zero();

  // ---------------------------------------------------------------------------
  // Chargement des animations au démarrage
  // ---------------------------------------------------------------------------

  @override
  Future<void> onLoad() async {
    // Initialisation des listes vides
    idleAnimation = [];
    walkAnimation = [];
    runAnimation = [];
    attackAnimation = [];

    // On charge une animation par ligne (direction) du spritesheet
    for (var row = 0; row < _rows; row++) {
      // Cas particulier : la ligne 3 (haut) de l'idle n'a que 3 frames
      final idleColumns = (row == 3) ? 3 : idleAnimationColumns;

      // --- Animation IDLE (repos) ---
      idleAnimation.add(
        await SpriteAnimation.load(
          idleAnimationPath,
          SpriteAnimationData.sequenced(
            amount: idleColumns, // Nombre de frames
            stepTime: stepTime, // Durée par frame
            textureSize: Vector2(
              _frameWidth,
              _frameHeight,
            ), // Taille d'une frame
            texturePosition: Vector2(
              0,
              row * _frameHeight,
            ), // Décalage Y selon la ligne
            loop: true, // Boucle infinie
          ),
        ),
      );

      // --- Animation WALK (marche) ---
      walkAnimation.add(
        await SpriteAnimation.load(
          walkAnimationPath,
          SpriteAnimationData.sequenced(
            amount: walkAnimationColumns,
            stepTime: stepTime,
            textureSize: Vector2(_frameWidth, _frameHeight),
            texturePosition: Vector2(0, row * _frameHeight),
            loop: true,
          ),
        ),
      );

      // --- Animation RUN (course) ---
      // stepTime plus court (0.07s) pour une animation plus rapide
      runAnimation.add(
        await SpriteAnimation.load(
          runAnimationPath,
          SpriteAnimationData.sequenced(
            amount: runAnimationColumns,
            stepTime: 0.07,
            textureSize: Vector2(_frameWidth, _frameHeight),
            texturePosition: Vector2(0, row * _frameHeight),
            loop: true,
          ),
        ),
      );

      // --- Animation ATTACK (attaque) ---
      // loop: false → l'animation ne joue qu'une seule fois
      attackAnimation.add(
        await SpriteAnimation.load(
          attackAnimationPath,
          SpriteAnimationData.sequenced(
            amount: attackAnimationColumns,
            stepTime: 0.1,
            textureSize: Vector2(_frameWidth, _frameHeight),
            texturePosition: Vector2(0, row * _frameHeight),
            loop: false,
          ),
        ),
      );
    }

    // On démarre avec l'animation idle (repos) face vers le bas (ligne 0)
    animation = idleAnimation[currentRow];
    playing = true;

  // ---------------------------------------------------------------------------
  // Gestion de la HITBOX player
  // ---------------------------------------------------------------------------

    /// la taille de la frame du personnage 192x192
    add(RectangleHitbox(
      size: Vector2(32, 32),
      position: Vector2(80, 110),),);
 }


  // ---------------------------------------------------------------------------
  // Gestion des collisions entre 2 HITBOX
  // ---------------------------------------------------------------------------
 @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollision(intersectionPoints, other);

    if (other is CollisionBlock) {
      position = _lastPosition;
    }
  }
  // ---------------------------------------------------------------------------
  // Gestion de l'attaque
  // ---------------------------------------------------------------------------

  /// Déclenche l'animation d'attaque.
  /// Ignore les appels si une attaque est déjà en cours.
  void attack() {
    if (isAttacking) return; // Empêche le spam d'attaques
    isAttacking = true;

    // Lance l'animation d'attaque dans la direction actuelle
    animation = attackAnimation[currentRow];
    animationTicker!.reset(); // Repart du début de l'animation

    // Callback appelé quand l'animation d'attaque se termine :
    // on repasse à l'animation de mouvement ou d'idle
    animationTicker!.onComplete = () {
      isAttacking = false;
      animation = isMoving
          ? (isRunning ? runAnimation[currentRow] : walkAnimation[currentRow])
          : idleAnimation[currentRow];
    };
  }

  // ---------------------------------------------------------------------------
  // Boucle de mise à jour (appelée à chaque frame du jeu)
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    // Appel au parent pour mettre à jour l'animation en cours
    super.update(dt);

    // Récupère l'entrée du joystick (vecteur normalisé entre 0 et 1)
    final input = joystick.relativeDelta;
    final distance =
        input.length; // Intensité du joystick (0 = neutre, 1 = max)

    // Détermine si le joueur bouge et s'il court
    final moving = distance > 0.01; // Petite zone morte pour éviter le bruit
    final running = distance > _runThreshold; // Au-delà du seuil → course

    if (moving) {
      // Calcul du déplacement : direction normalisée × vitesse × temps écoulé
      final speed = running ? _runSpeed : _walkSpeed;
      //COLLISION : et regardant la position actuelle
      _lastPosition = position.clone();
      // Sauvegarde de la position actuelle avant de se déplacer
      position += input.normalized() * speed * dt;

      // Met à jour la direction (ligne du spritesheet) selon l'entrée
      currentRow = _rowsFromInput(input);
      isMoving = true;
      isRunning = running;
    } else {
      isMoving = false;
      isRunning = false;
    }

    // Si une attaque est en cours, on ne change pas l'animation
    if (isAttacking) return;

    // Sélection de l'animation selon l'état actuel
    if (moving) {
      animation = running
          ? runAnimation[currentRow] // Course
          : walkAnimation[currentRow]; // Marche
    } else {
      animation = idleAnimation[currentRow]; // Repos
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaire : convertit la direction du joystick en index de ligne
  // ---------------------------------------------------------------------------

  /// Retourne l'index de la ligne du spritesheet correspondant
  /// à la direction dominante du vecteur d'entrée.
  ///   0 = bas   (Y positif vers le bas dans Flame)
  ///   1 = gauche
  ///   2 = droite
  ///   3 = haut
  int _rowsFromInput(Vector2 input) {
    if (input.x.abs() > input.y.abs()) {
      // Mouvement principalement horizontal
      return input.x > 0 ? 2 : 1; // Droite ou Gauche
    } else {
      // Mouvement principalement vertical
      return input.y > 0 ? 0 : 3; // Bas ou Haut
    }
  }
}
