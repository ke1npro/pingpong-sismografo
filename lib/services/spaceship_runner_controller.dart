import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/spaceship_runner_models.dart';
import 'sensor_service.dart';

/// Pure state and physics controller for the Spaceship Runner minigame.
///
/// Features:
/// - Continuous horizontal steering ($x \in [-0.92, 0.92]$) driven strictly by X-axis tilt.
/// - STRICT ZERO Z-AXIS ISOLATION: Operates purely on X-axis tilt (`tiltX`).
///   No Z-axis sensors, inputs, getters, or computations are ever accessed or referenced.
/// - Exponential velocity damping with deadzone noise rejection.
/// - Continuous speed scaling over time: $V_{\text{scroll}}(t) = \min(1.10, 0.40 + 0.005t)$.
/// - Strictly monotonic distance scoring: $d(t + \Delta t) = d(t) + V_{\text{scroll}} \cdot \Delta t \cdot 100$.
/// - Circle-circle collision detection with 3 lives, 1.8s invulnerability, and particle burst.
/// - Session high score retention across restarts.
class SpaceshipRunnerController extends ChangeNotifier {
  final SensorService? sensorService;

  SpaceshipRunnerController({this.sensorService});

  // Game Lifecycle & Scoring
  RunnerGameState _state = RunnerGameState.ready;
  int _lives = 3;
  double _distance = 0.0;
  int _score = 0;
  int _sessionHighScore = 0;
  double _gameTime = 0.0;

  // Spaceship Physics (Strictly X-Axis Only)
  double _shipX = 0.0;
  double _shipVx = 0.0;
  double _simulatedTiltX = 0.0;

  static const double shipHalfWidth = 0.08;
  static const double shipXBound = 0.92;
  static const double shipY = 0.82;
  static const double shipCollisionRadius = 0.05;
  static const double maxVelocity = 2.4;
  static const double dampingFactor = 14.0;
  static const double deadzone = 0.08;

  // Invulnerability
  static const double invulnerabilityDuration = 1.8;
  double _invulnerableTimer = 0.0;

  // Obstacles & Scrolling
  double _scrollSpeed = 0.40;
  double _spawnTimer = 0.0;
  int _nextAsteroidId = 0;
  final List<Asteroid> _asteroids = [];
  final List<SpaceParticle> _particles = [];
  final math.Random _random = math.Random();

  // Public Getters (ZERO Z-AXIS REFERENCES)
  RunnerGameState get state => _state;
  int get lives => _lives;
  double get distance => _distance;
  int get score => _score;
  int get sessionHighScore => _sessionHighScore;
  double get gameTime => _gameTime;
  double get shipX => _shipX;
  double get shipVx => _shipVx;
  double get scrollSpeed => _scrollSpeed;
  double get simulatedTiltX => _simulatedTiltX;
  bool get isInvulnerable => _invulnerableTimer > 0;
  double get invulnerableTimer => _invulnerableTimer;
  List<Asteroid> get asteroids => List.unmodifiable(_asteroids);
  List<SpaceParticle> get particles => List.unmodifiable(_particles);

  /// Sets on-screen simulated tilt in the range [-1.0, 1.0].
  void setSimulatedTilt(double tiltX) {
    _simulatedTiltX = tiltX.clamp(-1.0, 1.0);
    notifyListeners();
  }

  /// Clears explicit simulation override, allowing physical tilt when available.
  void clearSimulatedTilt() {
    _simulatedTiltX = 0.0;
    notifyListeners();
  }

  /// Starts or restarts the game loop from initial conditions while preserving high score.
  void startGame() {
    _state = RunnerGameState.playing;
    _lives = 3;
    _distance = 0.0;
    _score = 0;
    _gameTime = 0.0;
    _shipX = 0.0;
    _shipVx = 0.0;
    _scrollSpeed = 0.40;
    _invulnerableTimer = 0.0;
    _spawnTimer = 0.0;
    _asteroids.clear();
    _particles.clear();
    notifyListeners();
  }

  /// Restarts the minigame after game over or from pause menu.
  void restart() {
    startGame();
  }

  /// Clears active asteroids (useful for test isolation and reset transitions).
  void clearAsteroids() {
    _asteroids.clear();
    notifyListeners();
  }

  /// Pauses active gameplay.
  void pauseGame() {
    if (_state == RunnerGameState.playing) {
      _state = RunnerGameState.paused;
      notifyListeners();
    }
  }

  /// Resumes paused gameplay.
  void resumeGame() {
    if (_state == RunnerGameState.paused) {
      _state = RunnerGameState.playing;
      notifyListeners();
    }
  }

  /// Resolves effective X-axis tilt input from external parameter, simulation dock,
  /// or hardware accelerometer X reading.
  double _resolveActiveTiltX({double? externalTiltX}) {
    if (externalTiltX != null) {
      return externalTiltX.clamp(-1.0, 1.0);
    }
    if (_simulatedTiltX != 0.0) {
      return _simulatedTiltX.clamp(-1.0, 1.0);
    }
    // Read physical hardware X-axis tilt if available
    final sensor = sensorService;
    if (sensor != null && sensor.isRealSensorAvailable) {
      // 7.0 m/s^2 corresponds to ~45 degree comfortable phone tilt
      return (sensor.x / 7.0).clamp(-1.0, 1.0);
    }
    return _simulatedTiltX.clamp(-1.0, 1.0);
  }

  /// Primary physics and state update tick.
  ///
  /// Strictly isolates the X-axis (`tiltX`).
  void update(double dt, {double? externalTiltX}) {
    if (_state != RunnerGameState.playing) return;
    if (dt <= 0) return;

    final double activeTiltX = _resolveActiveTiltX(externalTiltX: externalTiltX);
    _gameTime += dt;

    // 1. Continuous Speed Scaling & Monotonic Scoring
    _scrollSpeed = math.min(1.10, 0.40 + 0.005 * _gameTime);
    _distance += _scrollSpeed * dt * 100.0;
    _score = _distance.floor();
    if (_score > _sessionHighScore) {
      _sessionHighScore = _score;
    }

    // 2. Invulnerability Timer
    if (_invulnerableTimer > 0) {
      _invulnerableTimer -= dt;
      if (_invulnerableTimer < 0) {
        _invulnerableTimer = 0.0;
      }
    }

    // 3. Continuous Horizontal Movement (Exponential Damping + Deadzone)
    double targetU = 0.0;
    if (activeTiltX.abs() > deadzone) {
      targetU = activeTiltX.sign * ((activeTiltX.abs() - deadzone) / (1.0 - deadzone));
    }
    final double targetVx = targetU * maxVelocity;
    _shipVx += (targetVx - _shipVx) * (1.0 - math.exp(-dampingFactor * dt));

    _shipX += _shipVx * dt;
    if (_shipX <= -shipXBound) {
      _shipX = -shipXBound;
      if (_shipVx < 0) _shipVx = 0.0;
    } else if (_shipX >= shipXBound) {
      _shipX = shipXBound;
      if (_shipVx > 0) _shipVx = 0.0;
    }

    // 4. Obstacle Spawning
    _spawnTimer += dt;
    final double currentSpawnInterval = math.max(0.42, 1.30 - 0.008 * _gameTime);
    if (_spawnTimer >= currentSpawnInterval) {
      _spawnTimer = 0.0;
      _spawnAsteroid();
    }

    // 5. Update Obstacles & Collision Check
    final List<Asteroid> remainingAsteroids = [];
    for (final asteroid in _asteroids) {
      asteroid.y += _scrollSpeed * dt;
      asteroid.rotation += asteroid.rotationSpeed * dt;

      // Circle-Circle collision approximation
      final double dx = _shipX - asteroid.x;
      final double dy = shipY - asteroid.y;
      final double distSq = dx * dx + dy * dy;
      final double collideDist = shipCollisionRadius + asteroid.radius;

      if (_invulnerableTimer <= 0 && distSq <= (collideDist * collideDist)) {
        // Impact occurred
        _lives--;
        _invulnerableTimer = invulnerabilityDuration;
        _spawnExplosion(asteroid.x, asteroid.y);
        if (_lives <= 0) {
          _state = RunnerGameState.gameOver;
        }
        continue; // Despawn collided asteroid
      }

      // Keep asteroid if still in bounds (despawn after passing bottom screen margin)
      if (asteroid.y <= 1.25) {
        remainingAsteroids.add(asteroid);
      }
    }
    _asteroids
      ..clear()
      ..addAll(remainingAsteroids);

    // 6. Update Particle Physics
    _updateParticles(dt);

    notifyListeners();
  }

  /// Spawns a procedural irregular asteroid above the screen.
  void _spawnAsteroid() {
    final double x = (_random.nextDouble() * 1.7) - 0.85;
    final double radius = 0.038 + (_random.nextDouble() * 0.046);
    final List<double> offsets = List.generate(
      8,
      (_) => 0.78 + (_random.nextDouble() * 0.44),
    );

    _asteroids.add(Asteroid(
      id: _nextAsteroidId++,
      x: x,
      y: -0.18,
      radius: radius,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 3.2,
      vertexRadiusOffsets: offsets,
    ));
  }

  /// Injects an asteroid at a precise normalized coordinate for deterministic unit testing.
  void spawnAsteroidAt(double x, double y, {double radius = 0.05}) {
    _asteroids.add(Asteroid(
      id: _nextAsteroidId++,
      x: x,
      y: y,
      radius: radius,
      rotation: 0.0,
      rotationSpeed: 0.0,
      vertexRadiusOffsets: List.filled(8, 1.0),
    ));
    notifyListeners();
  }

  /// Spawns explosion spark particles at normalized coordinate (x, y).
  void _spawnExplosion(double x, double y) {
    const List<int> neonColors = [
      0xFFFF1744, // Neon Red
      0xFFFFD600, // Neon Amber
      0xFF00F0FF, // Neon Cyan
      0xFFFF007F, // Neon Magenta
    ];

    for (int i = 0; i < 22; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double speed = 0.25 + (_random.nextDouble() * 0.65);
      final int colorValue = neonColors[i % neonColors.length];

      _particles.add(SpaceParticle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        life: 1.0,
        maxLife: 0.45 + (_random.nextDouble() * 0.35),
        colorValue: colorValue,
      ));
    }
  }

  /// Updates particle velocity and lifecycle decay.
  void _updateParticles(double dt) {
    final List<SpaceParticle> remaining = [];
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt / p.maxLife;
      if (p.life > 0) {
        remaining.add(p);
      }
    }
    _particles
      ..clear()
      ..addAll(remaining);
  }
}
