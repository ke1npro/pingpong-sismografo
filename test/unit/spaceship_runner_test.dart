import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpong_sismografo/models/spaceship_runner_models.dart';
import 'package:pingpong_sismografo/services/sensor_service.dart';
import 'package:pingpong_sismografo/services/spaceship_runner_controller.dart';

class TrackingSensorService implements SensorService {
  int xAccessCount = 0;
  int zAccessCount = 0;

  @override
  double get x {
    xAccessCount++;
    return 3.5;
  }

  @override
  double get z {
    zAccessCount++;
    return 9.8;
  }

  @override
  bool get isRealSensorAvailable => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SpaceshipRunnerController - State Lifecycle & Initialization', () {
    test('Initializes with default parameters', () {
      final controller = SpaceshipRunnerController();

      expect(controller.state, equals(RunnerGameState.ready));
      expect(controller.lives, equals(3));
      expect(controller.score, equals(0));
      expect(controller.sessionHighScore, equals(0));
      expect(controller.distance, equals(0.0));
      expect(controller.scrollSpeed, equals(0.40));
      expect(controller.shipX, equals(0.0));
      expect(controller.shipVx, equals(0.0));
      expect(controller.isInvulnerable, isFalse);
      expect(controller.asteroids, isEmpty);
      expect(controller.particles, isEmpty);
    });

    test('startGame sets state to playing and resets active run values', () {
      final controller = SpaceshipRunnerController();
      controller.startGame();

      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.lives, equals(3));
      expect(controller.score, equals(0));
      expect(controller.distance, equals(0.0));
      expect(controller.scrollSpeed, equals(0.40));
    });

    test('pauseGame and resumeGame toggle pause state cleanly', () {
      final controller = SpaceshipRunnerController()..startGame();

      controller.pauseGame();
      expect(controller.state, equals(RunnerGameState.paused));

      // Updating while paused does not advance distance or time
      final initialDist = controller.distance;
      controller.update(0.1);
      expect(controller.distance, equals(initialDist));

      controller.resumeGame();
      expect(controller.state, equals(RunnerGameState.playing));
      controller.update(0.1);
      expect(controller.distance, greaterThan(initialDist));
    });
  });

  group('SpaceshipRunnerController - Continuous Horizontal Movement & Clamping', () {
    test('Tilt within deadzone (<= 0.08) results in zero target velocity', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Apply tilt inside deadzone
      controller.setSimulatedTilt(0.05);
      controller.update(0.05);

      expect(controller.shipVx, equals(0.0));
      expect(controller.shipX, equals(0.0));

      controller.setSimulatedTilt(-0.07);
      controller.update(0.05);

      expect(controller.shipVx, equals(0.0));
      expect(controller.shipX, equals(0.0));
    });

    test('Right tilt accelerates ship rightward and updates shipX continuously', () {
      final controller = SpaceshipRunnerController()..startGame();

      controller.setSimulatedTilt(1.0);
      controller.update(0.1);

      expect(controller.shipVx, greaterThan(0.0));
      expect(controller.shipX, greaterThan(0.0));
    });

    test('Left tilt accelerates ship leftward and updates shipX continuously', () {
      final controller = SpaceshipRunnerController()..startGame();

      controller.setSimulatedTilt(-1.0);
      controller.update(0.1);

      expect(controller.shipVx, lessThan(0.0));
      expect(controller.shipX, lessThan(0.0));
    });

    test('Hard edge clamping stops ship at +0.92 and zeroes positive velocity', () {
      final controller = SpaceshipRunnerController()..startGame();

      controller.setSimulatedTilt(1.0);
      // Simulate 2 seconds of full rightward tilt
      for (int i = 0; i < 40; i++) {
        controller.update(0.05);
      }

      expect(controller.shipX, equals(SpaceshipRunnerController.shipXBound));
      expect(controller.shipX, closeTo(0.92, 0.001));
      expect(controller.shipVx, equals(0.0));

      // Reversing tilt immediately starts moving back left
      controller.setSimulatedTilt(-1.0);
      controller.update(0.1);
      expect(controller.shipVx, lessThan(0.0));
      expect(controller.shipX, lessThan(SpaceshipRunnerController.shipXBound));
    });

    test('Hard edge clamping stops ship at -0.92 and zeroes negative velocity', () {
      final controller = SpaceshipRunnerController()..startGame();

      controller.setSimulatedTilt(-1.0);
      // Simulate 2 seconds of full leftward tilt
      for (int i = 0; i < 40; i++) {
        controller.update(0.05);
      }

      expect(controller.shipX, equals(-SpaceshipRunnerController.shipXBound));
      expect(controller.shipX, closeTo(-0.92, 0.001));
      expect(controller.shipVx, equals(0.0));

      // Reversing tilt immediately starts moving back right
      controller.setSimulatedTilt(1.0);
      controller.update(0.1);
      expect(controller.shipVx, greaterThan(0.0));
      expect(controller.shipX, greaterThan(-SpaceshipRunnerController.shipXBound));
    });
  });

  group('SpaceshipRunnerController - Speed Scaling & Monotonic Scoring', () {
    test('Speed scales continuously over time from 0.40 up to max 1.10', () {
      final controller = SpaceshipRunnerController()..startGame();

      expect(controller.scrollSpeed, equals(0.40));

      // Advance by 20 seconds (scrollSpeed = 0.40 + 0.005 * 20 = 0.50)
      for (int i = 0; i < 200; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.scrollSpeed, closeTo(0.50, 0.005));

      // Advance by 150 more seconds (scrollSpeed should reach cap of 1.10)
      for (int i = 0; i < 1500; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.scrollSpeed, equals(1.10));
    });

    test('Distance and score increase strictly monotonically throughout gameplay', () {
      final controller = SpaceshipRunnerController()..startGame();

      double lastDistance = controller.distance;
      int lastScore = controller.score;

      for (int step = 0; step < 100; step++) {
        controller.update(0.033);
        expect(controller.distance, greaterThan(lastDistance),
            reason: 'Distance must strictly increase at step $step');
        expect(controller.score, greaterThanOrEqualTo(lastScore),
            reason: 'Score must be monotonically non-decreasing at step $step');
        expect(controller.score, equals(controller.distance.floor()));

        lastDistance = controller.distance;
        lastScore = controller.score;
      }
    });

    test('Session high score retains the highest achieved score across restarts', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Play to reach a score of at least 50
      for (int i = 0; i < 20; i++) {
        controller.update(0.1); // ~0.40 * 0.1 * 100 = 4 distance per step
      }
      final achievedScore = controller.score;
      expect(achievedScore, greaterThan(50));
      expect(controller.sessionHighScore, equals(achievedScore));

      // Restart
      controller.restart();
      expect(controller.score, equals(0));
      expect(controller.distance, equals(0.0));
      expect(controller.sessionHighScore, equals(achievedScore),
          reason: 'Session high score must be retained across restarts');
    });
  });

  group('SpaceshipRunnerController - Collision, Invulnerability & Game Over', () {
    test('Collision reduces lives by 1, spawns particles, and grants 1.8s invulnerability', () {
      final controller = SpaceshipRunnerController()..startGame();
      expect(controller.lives, equals(3));
      expect(controller.isInvulnerable, isFalse);

      // Spawn asteroid directly onto ship position (x = 0.0, y = 0.82)
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY, radius: 0.05);
      expect(controller.asteroids.length, equals(1));

      // Trigger update tick
      controller.update(0.016);

      // Verify collision outcome
      expect(controller.lives, equals(2));
      expect(controller.isInvulnerable, isTrue);
      expect(controller.invulnerableTimer, closeTo(1.8, 0.02));
      expect(controller.asteroids, isEmpty, reason: 'Collided asteroid should be despawned');
      expect(controller.particles, isNotEmpty, reason: 'Explosion particles should be spawned');
    });

    test('Invulnerability grace window ignores subsequent collisions for 1.8s', () {
      final controller = SpaceshipRunnerController()..startGame();

      // First collision
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);
      expect(controller.lives, equals(2));
      expect(controller.isInvulnerable, isTrue);

      // Immediate second asteroid while invulnerable
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.05);

      // Lives should still be 2
      expect(controller.lives, equals(2));
      expect(controller.invulnerableTimer, closeTo(1.8 - 0.05, 0.05));

      // Advance beyond 1.8s
      for (int i = 0; i < 40; i++) {
        controller.update(0.05);
      }
      expect(controller.isInvulnerable, isFalse);
      expect(controller.invulnerableTimer, equals(0.0));
    });

    test('3 collisions reduce lives to 0 and trigger gameOver state', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Hit 1
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);
      expect(controller.lives, equals(2));

      // Clear invulnerability for testing
      for (int i = 0; i < 40; i++) {
        controller.update(0.05);
      }

      // Hit 2
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);
      expect(controller.lives, equals(1));

      // Clear invulnerability
      for (int i = 0; i < 40; i++) {
        controller.update(0.05);
      }

      // Hit 3
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);
      expect(controller.lives, equals(0));
      expect(controller.state, equals(RunnerGameState.gameOver));

      // Updating after game over does not change score
      final finalScore = controller.score;
      controller.update(0.1);
      expect(controller.score, equals(finalScore));

      // Restart resets back to playing with 3 lives
      controller.restart();
      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.lives, equals(3));
      expect(controller.score, equals(0));
    });
  });

  group('SpaceshipRunnerController - Strict Zero Z-Axis Verification', () {
    test('Never references or reads Z-axis on SensorService', () {
      final trackingSensor = TrackingSensorService();
      final controller = SpaceshipRunnerController(sensorService: trackingSensor)
        ..startGame();

      // Run 60 simulation frames without explicit tilt so sensor is read
      for (int i = 0; i < 60; i++) {
        controller.update(0.016);
      }

      expect(trackingSensor.zAccessCount, equals(0),
          reason: 'Controller must NEVER access the Z-axis of SensorService');
      expect(trackingSensor.xAccessCount, greaterThan(0),
          reason: 'Controller must access the X-axis for tilt steering');
    });

    test('Static grep verification: runner files contain zero .z or _rawZ tokens', () {
      final runnerFiles = [
        'lib/models/spaceship_runner_models.dart',
        'lib/services/spaceship_runner_controller.dart',
        'lib/widgets/spaceship_painter.dart',
        'lib/widgets/runner_simulation_dock.dart',
        'lib/screens/spaceship_runner_screen.dart',
      ];

      for (final relativePath in runnerFiles) {
        final file = File(relativePath);
        expect(file.existsSync(), isTrue, reason: '$relativePath must exist');

        final content = file.readAsStringSync();
        // Check for .z or _rawZ patterns
        final zMatch = RegExp(r'(\.z\b|_rawZ\b)').firstMatch(content);
        expect(zMatch, isNull,
            reason: 'File $relativePath contains forbidden Z-axis token: ${zMatch?.group(0)}');
      }
    });
  });
}
