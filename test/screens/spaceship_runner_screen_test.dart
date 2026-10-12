import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpong_sismografo/models/spaceship_runner_models.dart';
import 'package:pingpong_sismografo/screens/spaceship_runner_screen.dart';
import 'package:pingpong_sismografo/services/spaceship_runner_controller.dart';
import 'package:pingpong_sismografo/theme/arcade_theme.dart';

void main() {
  group('SpaceshipRunnerScreen - Multi-Resolution Responsiveness & Layout', () {
    const targetResolutions = [
      Size(320, 568), // Small viewport (e.g. iPhone SE)
      Size(360, 640), // Standard viewport (e.g. baseline Android)
      Size(412, 915), // Tall viewport (e.g. Pixel 7 / modern Android)
    ];

    for (final size in targetResolutions) {
      testWidgets('Renders at ${size.width}x${size.height} with 0 RenderFlex overflows',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = SpaceshipRunnerController();

        await tester.pumpWidget(
          MaterialApp(
            theme: arcadeThemeData,
            home: SpaceshipRunnerScreen(controller: controller),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Assert no overflow exceptions occurred
        expect(tester.takeException(), isNull,
            reason: 'Layout must produce 0 RenderFlex overflows on $size');

        // Verify key structural components exist
        expect(find.text('COSMIC RUNNER'), findsOneWidget);
        expect(find.text('DIST (M)'), findsOneWidget);
        expect(find.text('TILT X SIM'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      });
    }
  });

  group('SpaceshipRunnerScreen - Simulation Dock Interaction', () {
    testWidgets('Steer Left button sets tilt to -1.0 on press and resets to 0.0 on release',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final leftButtonFinder = find.text('LEFT');
      expect(leftButtonFinder, findsOneWidget);

      // Press and hold LEFT button
      final gesture = await tester.startGesture(tester.getCenter(leftButtonFinder));
      await tester.pump();

      expect(controller.simulatedTiltX, equals(-1.0));

      // Release gesture
      await gesture.up();
      await tester.pump();

      expect(controller.simulatedTiltX, equals(0.0));
    });

    testWidgets('Steer Right button sets tilt to +1.0 on press and resets to 0.0 on release',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final rightButtonFinder = find.text('RIGHT');
      expect(rightButtonFinder, findsOneWidget);

      // Press and hold RIGHT button
      final gesture = await tester.startGesture(tester.getCenter(rightButtonFinder));
      await tester.pump();

      expect(controller.simulatedTiltX, equals(1.0));

      // Release gesture
      await gesture.up();
      await tester.pump();

      expect(controller.simulatedTiltX, equals(0.0));
    });

    testWidgets('Slider changes update simulated tilt continuously',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider rightward
      await tester.drag(sliderFinder, const Offset(60.0, 0.0));
      await tester.pump();

      expect(controller.simulatedTiltX, greaterThan(0.0));

      // Tap on reset indicator to re-center
      final readoutFinder = find.textContaining('+');
      expect(readoutFinder, findsOneWidget);
      await tester.tap(readoutFinder);
      await tester.pump();

      expect(controller.simulatedTiltX, equals(0.0));
    });
  });

  group('SpaceshipRunnerScreen - Overlays & Lifecycle', () {
    testWidgets('Pause button displays pause overlay and resume button restores flight',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.playing));
      expect(find.text('MISSION PAUSED'), findsNothing);

      // Tap pause button in AppBar
      final pauseActionFinder = find.byTooltip('Pause Mission');
      expect(pauseActionFinder, findsOneWidget);
      await tester.tap(pauseActionFinder);
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.paused));
      expect(find.text('MISSION PAUSED'), findsOneWidget);
      expect(find.text('RESUME FLIGHT'), findsOneWidget);

      // Tap resume button
      await tester.tap(find.text('RESUME FLIGHT'));
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.playing));
      expect(find.text('MISSION PAUSED'), findsNothing);
    });

    testWidgets('Game over displays destruction overlay and Launch Again button restarts',
        (WidgetTester tester) async {
      final controller = SpaceshipRunnerController();

      await tester.pumpWidget(
        MaterialApp(
          theme: arcadeThemeData,
          home: SpaceshipRunnerScreen(controller: controller),
        ),
      );
      await tester.pump();

      // Trigger 3 collisions to cause Game Over
      for (int i = 0; i < 3; i++) {
        controller.spawnAsteroidAt(0.0, SpaceshipRunnerController.shipY);
        controller.update(0.016);
        // Step forward beyond invulnerability
        for (int step = 0; step < 40; step++) {
          controller.update(0.05);
        }
      }
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.gameOver));
      expect(find.text('HULL DESTROYED'), findsOneWidget);
      expect(find.text('MISSION TERMINATED IN DEEP SPACE'), findsOneWidget);
      expect(find.text('LAUNCH AGAIN'), findsOneWidget);

      // Tap LAUNCH AGAIN
      await tester.tap(find.text('LAUNCH AGAIN'));
      await tester.pump();

      expect(controller.state, equals(RunnerGameState.playing));
      expect(controller.lives, equals(3));
      expect(find.text('HULL DESTROYED'), findsNothing);
    });
  });
}
