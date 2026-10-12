import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpong_sismografo/models/spaceship_runner_models.dart';
import 'package:pingpong_sismografo/screens/spaceship_runner_screen.dart';
import 'package:pingpong_sismografo/services/spaceship_runner_controller.dart';
import 'package:pingpong_sismografo/theme/arcade_theme.dart';
import 'package:pingpong_sismografo/widgets/runner_simulation_dock.dart';

void main() {
  group('Adversarial Test Suite - Milestone 2 Screen Responsiveness & Viewports', () {
    const targetResolutions = [
      Size(320, 568), // Small / iPhone SE 1st gen
      Size(360, 640), // Standard / Android 360dp
      Size(412, 915), // Tall / Pixel 7 modern Android
    ];

    for (final size in targetResolutions) {
      testWidgets(
          'Viewport ${size.width}x${size.height} in PLAYING state produces 0 RenderFlex overflow',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = SpaceshipRunnerController()..startGame();

        await tester.pumpWidget(
          MaterialApp(
            theme: arcadeThemeData,
            home: SpaceshipRunnerScreen(controller: controller),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull,
            reason: 'Playing state on $size must produce 0 overflow exceptions');
        expect(find.byType(SpaceshipRunnerScreen), findsOneWidget);
        expect(find.text('COSMIC RUNNER'), findsOneWidget);
        expect(find.text('DIST (M)'), findsOneWidget);
        expect(find.text('TILT X SIM'), findsOneWidget);
      });

      testWidgets(
          'Viewport ${size.width}x${size.height} in PAUSED state produces 0 RenderFlex overflow',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = SpaceshipRunnerController()
          ..startGame()
          ..pauseGame();

        await tester.pumpWidget(
          MaterialApp(
            theme: arcadeThemeData,
            home: SpaceshipRunnerScreen(controller: controller),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull,
            reason: 'Paused overlay on $size must produce 0 overflow exceptions');
        expect(find.text('MISSION PAUSED'), findsOneWidget);
        expect(find.text('RESUME FLIGHT'), findsOneWidget);
      });

      testWidgets(
          'Viewport ${size.width}x${size.height} in GAMEOVER state produces 0 RenderFlex overflow',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = SpaceshipRunnerController()..startGame();

        // Cause 3 collisions to transition to game over
        for (int i = 0; i < 3; i++) {
          controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
          controller.update(0.016);
          // Advance past 1.8s grace
          for (int s = 0; s < 40; s++) {
            controller.update(0.05);
          }
        }

        expect(controller.state, equals(RunnerGameState.gameOver));

        await tester.pumpWidget(
          MaterialApp(
            theme: arcadeThemeData,
            home: SpaceshipRunnerScreen(controller: controller),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull,
            reason: 'GameOver overlay on $size must produce 0 overflow exceptions');
        expect(find.text('HULL DESTROYED'), findsOneWidget);
        expect(find.text('LAUNCH AGAIN'), findsOneWidget);
      });

      testWidgets(
          'Viewport ${size.width}x${size.height} with 5-digit score on GAMEOVER produces 0 overflow',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Test standard high arcade score: 10,000 m (5 digits)
        final controller5d = SpaceshipRunnerController()..startGame();
        controller5d.clearAsteroids();
        controller5d.update(100.0); // score ~ 10,000

        // Cause 3 collisions deterministically
        for (int hit = 0; hit < 3; hit++) {
          controller5d.clearAsteroids();
          controller5d.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
          controller5d.update(0.016);
          if (controller5d.state == RunnerGameState.playing) {
            for (int s = 0; s < 40; s++) {
              controller5d.clearAsteroids();
              controller5d.update(0.05);
            }
          }
        }
        expect(controller5d.state, equals(RunnerGameState.gameOver));

        await tester.pumpWidget(
          MaterialApp(
            theme: arcadeThemeData,
            home: SpaceshipRunnerScreen(controller: controller5d),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final err5d = tester.takeException();
        // ignore: avoid_print
        print('5-digit score (${controller5d.score} m) on $size exception: $err5d');
        expect(err5d, isNull,
            reason: 'GameOver overlay with large score on $size must not overflow');
        expect(find.text('HULL DESTROYED'), findsOneWidget);
        expect(find.text('DISTANCE'), findsOneWidget);
        expect(find.text('BEST RECORD'), findsOneWidget);
      });
    }
  });

  group('Adversarial Test Suite - Simulation Dock Controls in SpaceshipRunnerScreen', () {
    testWidgets('Steer Left button press/hold/release/cancel behavior',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController()..startGame();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final leftFinder = find.text('LEFT');
      expect(leftFinder, findsOneWidget);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(leftFinder));
      await tester.pump();
      expect(controller.simulatedTiltX, equals(-1.0));

      // Release
      await gesture.up();
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));

      // Press and cancel (pointer cancel)
      final gesture2 = await tester.startGesture(tester.getCenter(leftFinder));
      await tester.pump();
      expect(controller.simulatedTiltX, equals(-1.0));

      await gesture2.cancel();
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));
    });

    testWidgets('Steer Right button press/hold/release/cancel behavior',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController()..startGame();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final rightFinder = find.text('RIGHT');
      expect(rightFinder, findsOneWidget);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(rightFinder));
      await tester.pump();
      expect(controller.simulatedTiltX, equals(1.0));

      // Release
      await gesture.up();
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));

      // Press and cancel
      final gesture2 = await tester.startGesture(tester.getCenter(rightFinder));
      await tester.pump();
      expect(controller.simulatedTiltX, equals(1.0));

      await gesture2.cancel();
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));
    });

    testWidgets('Slider analog dragging and reset readout tap inside SpaceshipRunnerScreen',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController()..startGame();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Drag rightward
      await tester.drag(slider, const Offset(60.0, 0.0));
      await tester.pump();
      expect(controller.simulatedTiltX, greaterThan(0.0));

      // Tap reset readout badge to recenter to 0.0
      final resetBadgePos = find.textContaining('+');
      expect(resetBadgePos, findsOneWidget);
      await tester.tap(resetBadgePos);
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));

      // Drag leftward
      await tester.drag(slider, const Offset(-60.0, 0.0));
      await tester.pump();
      expect(controller.simulatedTiltX, lessThan(0.0));

      // Tap reset readout badge to recenter from negative
      final resetBadgeNeg = find.textContaining('-');
      expect(resetBadgeNeg, findsOneWidget);
      await tester.tap(resetBadgeNeg);
      await tester.pump();
      expect(controller.simulatedTiltX, equals(0.0));
    });

    testWidgets('Keyboard listeners handle ArrowLeft, ArrowRight, KeyA, KeyD',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController()..startGame();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: Scaffold(
            body: RunnerSimulationDock(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Verify KeyboardListener is in the tree
      expect(find.byType(KeyboardListener), findsOneWidget);

      // 1. ArrowLeft: KeyDown -> -1.0, KeyUp -> 0.0
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      // sendKeyEvent sends both down and up; let's test explicit down and up
      expect(controller.simulatedTiltX, equals(0.0));

      // Explicit down:
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      expect(controller.simulatedTiltX, equals(-1.0));

      await simulateKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      expect(controller.simulatedTiltX, equals(0.0));

      // 2. ArrowRight: KeyDown -> +1.0, KeyUp -> 0.0
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight);
      expect(controller.simulatedTiltX, equals(1.0));

      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(controller.simulatedTiltX, equals(0.0));

      // 3. KeyA: KeyDown -> -1.0, KeyUp -> 0.0
      await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
      expect(controller.simulatedTiltX, equals(-1.0));

      await simulateKeyUpEvent(LogicalKeyboardKey.keyA);
      expect(controller.simulatedTiltX, equals(0.0));

      // 4. KeyD: KeyDown -> +1.0, KeyUp -> 0.0
      await simulateKeyDownEvent(LogicalKeyboardKey.keyD);
      expect(controller.simulatedTiltX, equals(1.0));

      await simulateKeyUpEvent(LogicalKeyboardKey.keyD);
      expect(controller.simulatedTiltX, equals(0.0));

      // 5. Unrelated key (Space bar) must not alter tilt
      await simulateKeyDownEvent(LogicalKeyboardKey.space);
      expect(controller.simulatedTiltX, equals(0.0));

      await simulateKeyUpEvent(LogicalKeyboardKey.space);
      expect(controller.simulatedTiltX, equals(0.0));
    });
  });

  group('Adversarial Test Suite - Collision, Lives & Grace Period Stress', () {
    test('Collision reduces lives 3 -> 2 -> 1 -> 0, enforces 1.8s grace, triggers gameOver', () {
      final controller = SpaceshipRunnerController()..startGame();

      expect(controller.lives, equals(3));
      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.isInvulnerable, isFalse);

      // --- HIT 1 ---
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);

      expect(controller.lives, equals(2));
      expect(controller.isInvulnerable, isTrue);
      expect(controller.invulnerableTimer, closeTo(1.8, 0.02));
      expect(controller.particles.length, equals(22));

      // Multiple asteroids during invulnerability window MUST NOT decrease lives
      for (int i = 0; i < 5; i++) {
        controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
        controller.update(0.1);
        expect(controller.lives, equals(2),
            reason: 'Lives must remain at 2 during invulnerability window');
      }

      // Step forward until invulnerability expires
      while (controller.isInvulnerable) {
        controller.update(0.05);
      }
      expect(controller.isInvulnerable, isFalse);
      expect(controller.invulnerableTimer, equals(0.0));
      expect(controller.lives, equals(2));

      // --- HIT 2 ---
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);

      expect(controller.lives, equals(1));
      expect(controller.isInvulnerable, isTrue);

      // Step forward until invulnerability expires
      while (controller.isInvulnerable) {
        controller.update(0.05);
      }
      expect(controller.lives, equals(1));

      // --- HIT 3 (FATAL) ---
      controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
      controller.update(0.016);

      expect(controller.lives, equals(0));
      expect(controller.state, equals(RunnerGameState.gameOver));

      // Further update ticks while gameOver do not reduce lives below 0
      controller.update(0.1);
      expect(controller.lives, equals(0));
      expect(controller.state, equals(RunnerGameState.gameOver));
    });

    test('Restart resets game state completely while preserving session high score', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Play run 1 and accumulate distance
      for (int i = 0; i < 50; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }

      final run1Score = controller.score;
      expect(run1Score, greaterThan(100));
      expect(controller.sessionHighScore, equals(run1Score));

      // Collide 3 times to gameOver
      for (int i = 0; i < 3; i++) {
        controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
        controller.update(0.016);
        if (controller.state == RunnerGameState.playing) {
          while (controller.isInvulnerable) {
            controller.update(0.05);
          }
        }
      }
      expect(controller.state, equals(RunnerGameState.gameOver));

      final finalRun1Score = controller.score;
      expect(finalRun1Score, greaterThan(100));
      expect(controller.sessionHighScore, equals(finalRun1Score));

      // Trigger restart
      controller.restart();

      // Assert complete state reset
      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.lives, equals(3));
      expect(controller.score, equals(0));
      expect(controller.distance, equals(0.0));
      expect(controller.shipX, equals(0.0));
      expect(controller.shipVx, equals(0.0));
      expect(controller.scrollSpeed, equals(0.40));
      expect(controller.isInvulnerable, isFalse);
      expect(controller.asteroids, isEmpty);
      expect(controller.particles, isEmpty);

      // Assert session high score preserved
      expect(controller.sessionHighScore, equals(finalRun1Score));

      // Play run 2 with smaller score (does not overwrite higher sessionHighScore)
      for (int i = 0; i < 5; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.score, lessThan(finalRun1Score));
      expect(controller.sessionHighScore, equals(finalRun1Score));

      // Play further in run 2 until it beats finalRun1Score
      while (controller.score <= finalRun1Score) {
        controller.clearAsteroids();
        controller.update(0.1);
      }
      expect(controller.sessionHighScore, equals(controller.score));
    });

    testWidgets('Tapping LAUNCH AGAIN in UI resets state and preserves high score',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController()..startGame();

      // Accumulate score
      for (int i = 0; i < 30; i++) {
        controller.clearAsteroids();
        controller.update(0.1);
      }

      // End game
      for (int i = 0; i < 3; i++) {
        controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
        controller.update(0.016);
        if (controller.state == RunnerGameState.playing) {
          while (controller.isInvulnerable) {
            controller.update(0.05);
          }
        }
      }
      expect(controller.state, equals(RunnerGameState.gameOver));

      final achievedScore = controller.score;
      expect(achievedScore, greaterThan(50));
      expect(controller.sessionHighScore, equals(achievedScore));

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('HULL DESTROYED'), findsOneWidget);
      final launchButton = find.text('LAUNCH AGAIN');
      expect(launchButton, findsOneWidget);

      // Tap Launch Again
      await tester.tap(launchButton);
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.lives, equals(3));
      expect(controller.score, equals(0));
      expect(controller.sessionHighScore, equals(achievedScore));
      expect(find.text('HULL DESTROYED'), findsNothing);
    });
  });

  group('Adversarial Test Suite - Ship Boundary Clamping & Zero Z-Axis Invariance', () {
    test('Ship clamps at exact boundary [-0.92, 0.92] under extreme continuous steer', () {
      final controller = SpaceshipRunnerController()..startGame();

      // Steer hard left with large external tilt
      for (int i = 0; i < 50; i++) {
        controller.update(0.1, externalTiltX: -100.0);
      }
      expect(controller.shipX, equals(-0.92));
      expect(controller.shipVx, equals(0.0));

      // Steer hard right
      for (int i = 0; i < 100; i++) {
        controller.update(0.1, externalTiltX: 100.0);
      }
      expect(controller.shipX, equals(0.92));
      expect(controller.shipVx, equals(0.0));
    });

    test('Zero dt or negative dt updates are safely ignored without corruption', () {
      final controller = SpaceshipRunnerController()..startGame();
      final initDist = controller.distance;

      controller.update(0.0);
      expect(controller.distance, equals(initDist));

      controller.update(-0.5);
      expect(controller.distance, equals(initDist));
    });
  });
}
