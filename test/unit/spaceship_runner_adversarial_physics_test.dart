import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpong_sismografo/models/spaceship_runner_models.dart';
import 'package:pingpong_sismografo/services/sensor_service.dart';
import 'package:pingpong_sismografo/services/spaceship_runner_controller.dart';

/// Adversarial Mock Sensor Service that throws if Z-axis is ever touched.
class AdversarialZTrackingSensorService implements SensorService {
  int xAccessCount = 0;
  int yAccessCount = 0;
  int zAccessCount = 0;
  double simulatedX = 4.2;

  @override
  double get x {
    xAccessCount++;
    return simulatedX;
  }

  @override
  double get y {
    yAccessCount++;
    return 0.0;
  }

  @override
  double get z {
    zAccessCount++;
    throw StateError('STRICT ISOLATION VIOLATION: Spaceship Runner accessed Z-axis!');
  }

  @override
  bool get isRealSensorAvailable => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Objective 1: Extreme Steering Inputs & Hard Boundary Clamping [-0.92, 0.92]', () {
    test('Extreme positive inputs (+50.0, +1000.0, +1e6) hard-clamp shipX at exactly +0.92', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Test extreme external tilt values
      final extremeValues = [50.0, 100.0, 1000.0, 1e6];

      for (final tilt in extremeValues) {
        controller.startGame();

        for (int frame = 0; frame < 80; frame++) {
          final prevX = controller.shipX;
          controller.update(0.016, externalTiltX: tilt);

          // Ship must never exceed boundary
          expect(controller.shipX, lessThanOrEqualTo(SpaceshipRunnerController.shipXBound),
              reason: 'Frame $frame with tilt $tilt exceeded +0.92 boundary: ${controller.shipX}');
          expect(controller.shipX, greaterThanOrEqualTo(prevX),
              reason: 'Ship must monotonically move rightward until reaching boundary');
        }

        // Must be firmly clamped at exact boundary
        expect(controller.shipX, equals(SpaceshipRunnerController.shipXBound));
        expect(controller.shipX, equals(0.92));
        // Boundary collision zeroes rightward velocity
        expect(controller.shipVx, equals(0.0),
            reason: 'Positive velocity must be zeroed upon wall contact');
      }
    });

    test('Extreme negative inputs (-50.0, -1000.0, -1e6) hard-clamp shipX at exactly -0.92', () {
      final controller = SpaceshipRunnerController()..startGame();

      final extremeValues = [-50.0, -100.0, -1000.0, -1e6];

      for (final tilt in extremeValues) {
        controller.startGame();

        for (int frame = 0; frame < 80; frame++) {
          final prevX = controller.shipX;
          controller.update(0.016, externalTiltX: tilt);

          // Ship must never exceed left boundary
          expect(controller.shipX, greaterThanOrEqualTo(-SpaceshipRunnerController.shipXBound),
              reason: 'Frame $frame with tilt $tilt exceeded -0.92 boundary: ${controller.shipX}');
          expect(controller.shipX, lessThanOrEqualTo(prevX),
              reason: 'Ship must monotonically move leftward until reaching boundary');
        }

        // Must be firmly clamped at exact boundary
        expect(controller.shipX, equals(-SpaceshipRunnerController.shipXBound));
        expect(controller.shipX, equals(-0.92));
        // Boundary collision zeroes leftward velocity
        expect(controller.shipVx, equals(0.0),
            reason: 'Negative velocity must be zeroed upon wall contact');
      }
    });

    test('setSimulatedTilt clamps extreme inputs to [-1.0, 1.0] and bounds shipX', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Extreme simulated tilt
      controller.setSimulatedTilt(50.0);
      expect(controller.simulatedTiltX, equals(1.0));

      for (int i = 0; i < 50; i++) {
        controller.update(0.033);
      }
      expect(controller.shipX, equals(0.92));
      expect(controller.shipVx, equals(0.0));

      controller.setSimulatedTilt(-50.0);
      expect(controller.simulatedTiltX, equals(-1.0));

      for (int i = 0; i < 80; i++) {
        controller.update(0.033);
      }
      expect(controller.shipX, equals(-0.92));
      expect(controller.shipVx, equals(0.0));
    });

    test('Hardware accelerometer extreme values (sensor.x = +/- 50 m/s²) clamp cleanly', () {
      final trackingSensor = AdversarialZTrackingSensorService();
      final controller = SpaceshipRunnerController(sensorService: trackingSensor)..startGame();

      // Extreme hardware sensor X (+50.0 m/s²)
      trackingSensor.simulatedX = 50.0;
      for (int i = 0; i < 60; i++) {
        controller.update(0.02);
      }
      expect(controller.shipX, equals(0.92));
      expect(controller.shipVx, equals(0.0));

      // Extreme hardware sensor X (-50.0 m/s²)
      trackingSensor.simulatedX = -50.0;
      for (int i = 0; i < 100; i++) {
        controller.update(0.02);
      }
      expect(controller.shipX, equals(-0.92));
      expect(controller.shipVx, equals(0.0));
    });

    test('Immediate boundary detachment: reversing tilt breaks wall contact on next frame', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Pin against right wall
      for (int i = 0; i < 50; i++) {
        controller.update(0.02, externalTiltX: 50.0);
      }
      expect(controller.shipX, equals(0.92));
      expect(controller.shipVx, equals(0.0));

      // Steer left on the very next tick
      controller.update(0.02, externalTiltX: -1.0);
      expect(controller.shipVx, lessThan(0.0),
          reason: 'Ship velocity must immediately become negative');
      expect(controller.shipX, lessThan(0.92),
          reason: 'Ship position must immediately detach from right boundary');

      // Pin against left wall
      for (int i = 0; i < 80; i++) {
        controller.update(0.02, externalTiltX: -50.0);
      }
      expect(controller.shipX, equals(-0.92));
      expect(controller.shipVx, equals(0.0));

      // Steer right on the very next tick
      controller.update(0.02, externalTiltX: 1.0);
      expect(controller.shipVx, greaterThan(0.0),
          reason: 'Ship velocity must immediately become positive');
      expect(controller.shipX, greaterThan(-0.92),
          reason: 'Ship position must immediately detach from left boundary');
    });

    test('Continuous analog steering is non-quantized across fine tilt increments', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Sweep 50 fine tilt inputs between 0.10 and 0.90
      final List<double> resultingVelocities = [];
      for (int i = 0; i < 50; i++) {
        final tilt = 0.10 + (i / 50.0) * 0.80;
        controller.startGame(); // start from rest
        controller.update(0.05, externalTiltX: tilt);
        resultingVelocities.add(controller.shipVx);
      }

      // Assert strictly monotonic velocity growth (proves analog continuity, not discrete lanes)
      for (int i = 1; i < resultingVelocities.length; i++) {
        expect(resultingVelocities[i], greaterThan(resultingVelocities[i - 1]),
            reason: 'Velocity at step $i must be strictly greater than step ${i - 1} for analog responsiveness');
      }
    });

    test('Sudden massive dt spike does not penetrate boundary', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Normal flight to mid-screen
      controller.update(0.5, externalTiltX: 0.5);

      // Huge frame spike (e.g. 10 seconds of extreme tilt)
      controller.update(10.0, externalTiltX: 50.0);

      expect(controller.shipX, equals(0.92));
      expect(controller.shipVx, equals(0.0));

      controller.update(10.0, externalTiltX: -50.0);
      expect(controller.shipX, equals(-0.92));
      expect(controller.shipVx, equals(0.0));
    });
  });

  group('Objective 2: Strictly Monotonic Distance Accumulation d(t+dt) > d(t)', () {
    test('Assert d(t+dt) > d(t) for every active frame across 1000 frames with variable dt', () {
      final controller = SpaceshipRunnerController()..startGame();
      final rng = math.Random(1337);

      double prevDist = controller.distance;
      int prevScore = controller.score;

      for (int frame = 0; frame < 1000; frame++) {
        // Variable jittery dt in range [0.005, 0.050]
        final dt = 0.005 + rng.nextDouble() * 0.045;
        // Pseudo-random tilt input
        final tilt = (rng.nextDouble() * 2.0) - 1.0;

        // Clear procedural asteroids to ensure uninterrupted active flight
        controller.clearAsteroids();
        controller.update(dt, externalTiltX: tilt);

        // Core Contract Assertions for active frames:
        expect(controller.state, equals(RunnerGameState.playing));
        expect(controller.distance, greaterThan(prevDist),
            reason: 'Strict monotonic distance accumulation violated at frame $frame (dt=$dt)');
        expect(controller.score, greaterThanOrEqualTo(prevScore),
            reason: 'Monotonic score accumulation violated at frame $frame');
        expect(controller.score, equals(controller.distance.floor()),
            reason: 'Score must equal floor(distance)');

        prevDist = controller.distance;
        prevScore = controller.score;
      }
    });

    test('Distance continues strictly monotonic accumulation during collision and invulnerability', () {
      final controller = SpaceshipRunnerController()..startGame();

      double prevDist = controller.distance;

      // Collide 1: Asteroid on ship
      controller.spawnAsteroidAt(controller.shipX, SpaceshipRunnerController.shipY);
      controller.update(0.016);

      expect(controller.isInvulnerable, isTrue);
      expect(controller.distance, greaterThan(prevDist));
      prevDist = controller.distance;

      // 60 frames during active invulnerability
      for (int i = 0; i < 60; i++) {
        controller.update(0.016);
        expect(controller.distance, greaterThan(prevDist),
            reason: 'Distance must strictly increase even when invulnerable at tick $i');
        prevDist = controller.distance;
      }

      // Collide 2
      controller.spawnAsteroidAt(controller.shipX, SpaceshipRunnerController.shipY);
      controller.update(0.016);
      expect(controller.distance, greaterThan(prevDist));
    });

    test('Distance stops accumulating (does not increase or decrease) in non-playing states', () {
      final controller = SpaceshipRunnerController();

      // Ready state
      expect(controller.state, equals(RunnerGameState.ready));
      controller.update(0.1);
      expect(controller.distance, equals(0.0));

      // Playing state -> accumulates
      controller.startGame();
      controller.update(0.1);
      final distAfterPlay = controller.distance;
      expect(distAfterPlay, greaterThan(0.0));

      // Paused state -> frozen
      controller.pauseGame();
      expect(controller.state, equals(RunnerGameState.paused));
      controller.update(0.1);
      expect(controller.distance, equals(distAfterPlay));

      // Resume -> accumulates again
      controller.resumeGame();
      controller.update(0.1);
      final distAfterResume = controller.distance;
      expect(distAfterResume, greaterThan(distAfterPlay));

      // GameOver state -> frozen
      // Trigger 3 hits
      for (int i = 0; i < 3; i++) {
        controller.spawnAsteroidAt(controller.shipX, SpaceshipRunnerController.shipY);
        controller.update(0.016);
        for (int s = 0; s < 40; s++) {
          controller.update(0.05);
        }
      }
      expect(controller.state, equals(RunnerGameState.gameOver));
      final distAtGameOver = controller.distance;

      // Update in gameOver state
      controller.update(0.5);
      expect(controller.distance, equals(distAtGameOver),
          reason: 'Distance must not mutate in game over state');
    });
  });

  group('Objective 3: Speed Scaling Monotonicity & 1.10 Cap', () {
    test('Speed scaling function V_scroll(t) increases monotonically over time from 0.40', () {
      final controller = SpaceshipRunnerController()..startGame();

      double prevSpeed = controller.scrollSpeed;
      expect(prevSpeed, equals(0.40), reason: 'Initial scroll speed must be 0.40');

      // Step forward 200 seconds in 0.1s increments
      for (int step = 0; step < 2000; step++) {
        controller.clearAsteroids();
        controller.update(0.1);

        expect(controller.scrollSpeed, greaterThanOrEqualTo(prevSpeed),
            reason: 'Speed must be monotonically non-decreasing at step $step');
        expect(controller.scrollSpeed, lessThanOrEqualTo(1.10),
            reason: 'Speed must never exceed 1.10 cap at step $step');

        prevSpeed = controller.scrollSpeed;
      }
    });

    test('Speed cap at 1.10 is reached at t=140s and stays strictly capped indefinitely', () {
      final controller = SpaceshipRunnerController()..startGame();

      // At t = 100s: V = 0.40 + 0.005 * 100 = 0.90
      for (int i = 0; i < 1000; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.scrollSpeed, closeTo(0.90, 0.002));

      // At t = 140s: V = 0.40 + 0.005 * 140 = 1.10
      for (int i = 0; i < 400; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.scrollSpeed, closeTo(1.10, 1e-6));

      // Advance one more tick past 140s so min(1.10, ...) hits the exact double literal cap
      controller.update(0.1);
      expect(controller.scrollSpeed, equals(1.10));

      // Further long run (up to t = 500s) remains clamped at 1.10
      for (int i = 0; i < 3600; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
        expect(controller.scrollSpeed, equals(1.10),
            reason: 'Speed must remain strictly 1.10 after reaching cap');
      }
    });
  });

  group('Objective 4: Strict Zero Z-Axis Reading Isolation (Empirical & AST)', () {
    test('Adversarial mock sensor verifies 0 Z-axis reads across all game operations', () {
      final trackingSensor = AdversarialZTrackingSensorService();
      final controller = SpaceshipRunnerController(sensorService: trackingSensor);

      // Verify ready state
      expect(controller.state, equals(RunnerGameState.ready));
      controller.update(0.016);

      // Start game
      controller.startGame();

      // Run 200 simulated frames using hardware sensor tilt
      for (int frame = 0; frame < 200; frame++) {
        controller.update(0.016);
      }

      // Pause and resume
      controller.pauseGame();
      controller.update(0.016);
      controller.resumeGame();
      controller.update(0.016);

      // Collisions and Game Over
      for (int i = 0; i < 3; i++) {
        controller.spawnAsteroidAt(controller.shipX, SpaceshipRunnerController.shipY);
        controller.update(0.016);
        for (int s = 0; s < 40; s++) {
          controller.update(0.05);
        }
      }
      expect(controller.state, equals(RunnerGameState.gameOver));

      // Restart
      controller.restart();
      for (int frame = 0; frame < 50; frame++) {
        controller.update(0.016);
      }

      // Rigorous Assertions:
      expect(trackingSensor.zAccessCount, equals(0),
          reason: 'Spaceship Runner MUST NEVER read or access the Z-axis of SensorService');
      expect(trackingSensor.xAccessCount, greaterThan(200),
          reason: 'Spaceship Runner must read the X-axis for tilt steering');
    });

    test('Source code AST & Regex audit: zero Z-axis tokens across all runner files', () {
      final runnerSourceFiles = [
        'lib/models/spaceship_runner_models.dart',
        'lib/services/spaceship_runner_controller.dart',
        'lib/widgets/spaceship_painter.dart',
        'lib/widgets/runner_simulation_dock.dart',
        'lib/screens/spaceship_runner_screen.dart',
      ];

      final forbiddenPatterns = [
        RegExp(r'\.z\b'),
        RegExp(r'_rawZ\b'),
        RegExp(r'_gravZ\b'),
        RegExp(r'dynZ\b'),
        RegExp(r'simZ\b'),
        RegExp(r'tiltZ\b'),
      ];

      for (final filePath in runnerSourceFiles) {
        final file = File(filePath);
        expect(file.existsSync(), isTrue, reason: 'Source file must exist: $filePath');

        final lines = file.readAsLinesSync();
        for (int lineNum = 1; lineNum <= lines.length; lineNum++) {
          final line = lines[lineNum - 1];

          // Skip comments
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///') || trimmed.startsWith('*')) {
            continue;
          }

          for (final pattern in forbiddenPatterns) {
            final match = pattern.firstMatch(line);
            expect(match, isNull,
                reason: 'Forbidden Z-axis token "${match?.group(0)}" in $filePath:$lineNum: "$line"');
          }
        }
      }
    });
  });
}
