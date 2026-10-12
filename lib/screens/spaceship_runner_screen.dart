import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/spaceship_runner_models.dart';
import '../services/sensor_service.dart';
import '../services/spaceship_runner_controller.dart';
import '../theme/arcade_theme.dart';
import '../widgets/arcade_components.dart';
import '../widgets/runner_simulation_dock.dart';
import '../widgets/spaceship_painter.dart';

/// Full arcade Spaceship Runner screen (R2 & AC5).
///
/// Features:
/// - VSync 60fps frame-delta synchronization via Flutter's [Ticker].
/// - Strict zero Z-axis reading isolation.
/// - Overflow-free responsive layout on small (320x568), standard (360x640),
///   and tall (412x915) mobile displays.
/// - Integrated [ArcadeHUD], [CustomPaint] canvas, [RunnerSimulationDock],
///   and semi-transparent Game Over / Pause overlays.
class SpaceshipRunnerScreen extends StatefulWidget {
  final SpaceshipRunnerController? controller;

  const SpaceshipRunnerScreen({
    super.key,
    this.controller,
  });

  @override
  State<SpaceshipRunnerScreen> createState() => _SpaceshipRunnerScreenState();
}

class _SpaceshipRunnerScreenState extends State<SpaceshipRunnerScreen>
    with SingleTickerProviderStateMixin {
  late final SpaceshipRunnerController _controller;
  late final bool _isInternalController;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isInternalController = false;
    } else {
      _controller = SpaceshipRunnerController(sensorService: SensorService());
      _isInternalController = true;
    }

    _ticker = createTicker(_onTick);
    _ticker.start();

    // Auto-commence mission if in ready state
    if (_controller.state == RunnerGameState.ready) {
      _controller.startGame();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      _controller.update(0.016);
      return;
    }

    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    // Clamp frame delta to protect against background tab pause spikes
    _controller.update(dt.clamp(0.001, 0.05));
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadeColors.spaceBackground,
      appBar: AppBar(
        title: const Text(
          'COSMIC RUNNER',
          style: ArcadeTypography.headerDisplay,
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final isPaused = _controller.state == RunnerGameState.paused;
              return IconButton(
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: ArcadeColors.neonCyan,
                ),
                tooltip: isPaused ? 'Resume Mission' : 'Pause Mission',
                onPressed: () {
                  if (_controller.state == RunnerGameState.playing) {
                    _controller.pauseGame();
                  } else if (_controller.state == RunnerGameState.paused) {
                    _controller.resumeGame();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                // 1. Compact HUD (Height: 42px, FittedBox protection)
                ArcadeHUD(
                  score: _controller.score,
                  highScore: _controller.sessionHighScore,
                  lives: _controller.lives,
                  maxLives: 3,
                  scoreLabel: 'DIST (M)',
                  accentColor: ArcadeColors.neonAmber,
                  centerWidget: _buildSpeedPill(_controller.scrollSpeed),
                ),

                // 2. Responsive Game Canvas with Overlays
                Expanded(
                  child: Stack(
                    children: [
                      // Active Vector Graphics Canvas
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SpaceshipPainter(controller: _controller),
                        ),
                      ),

                      // Game Over Overlay
                      if (_controller.state == RunnerGameState.gameOver)
                        _buildGameOverOverlay(),

                      // Paused Overlay
                      if (_controller.state == RunnerGameState.paused)
                        _buildPausedOverlay(),
                    ],
                  ),
                ),

                // 3. Responsive On-Screen Simulation Dock (Height: 56px)
                RunnerSimulationDock(
                  controller: _controller,
                  height: 56.0,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedPill(double scrollSpeed) {
    final int speedKmh = (scrollSpeed * 220).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: ArcadeColors.neonCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: ArcadeColors.neonCyan.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.speed_rounded,
            size: 11.0,
            color: ArcadeColors.neonCyan,
          ),
          const SizedBox(width: 4.0),
          Text(
            '$speedKmh KM/H',
            style: ArcadeTypography.hudNumberSmall.copyWith(
              color: ArcadeColors.neonCyan,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: ArcadeColors.spaceVoid.withValues(alpha: 0.85),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: NeonPanel(
          accentColor: ArcadeColors.neonRed,
          glowIntensity: 0.6,
          padding: const EdgeInsets.all(20.0),
          borderRadius: 16.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 38.0,
                color: ArcadeColors.neonRed,
              ),
              const SizedBox(height: 8.0),
              Text(
                'HULL DESTROYED',
                style: ArcadeTypography.headerDisplay.copyWith(
                  color: ArcadeColors.neonRed,
                  fontSize: 18.0,
                ),
              ),
              const SizedBox(height: 4.0),
              const Text(
                'MISSION TERMINATED IN DEEP SPACE',
                style: ArcadeTypography.microLabel,
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScoreStatCard(
                    title: 'DISTANCE',
                    value: '${_controller.score} m',
                    color: ArcadeColors.neonAmber,
                  ),
                  const SizedBox(width: 14.0),
                  _buildScoreStatCard(
                    title: 'BEST RECORD',
                    value: '${_controller.sessionHighScore} m',
                    color: ArcadeColors.neonCyan,
                  ),
                ],
              ),
              const SizedBox(height: 18.0),
              ArcadeButton(
                label: 'LAUNCH AGAIN',
                icon: Icons.replay_rounded,
                accentColor: ArcadeColors.neonCyan,
                onPressed: () {
                  _controller.restart();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      color: ArcadeColors.spaceVoid.withValues(alpha: 0.82),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: NeonPanel(
          accentColor: ArcadeColors.neonLime,
          padding: const EdgeInsets.all(20.0),
          borderRadius: 16.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_outline_rounded,
                size: 36.0,
                color: ArcadeColors.neonLime,
              ),
              const SizedBox(height: 8.0),
              Text(
                'MISSION PAUSED',
                style: ArcadeTypography.headerDisplay.copyWith(
                  color: ArcadeColors.neonLime,
                  fontSize: 18.0,
                ),
              ),
              const SizedBox(height: 16.0),
              ArcadeButton(
                label: 'RESUME FLIGHT',
                icon: Icons.play_arrow_rounded,
                accentColor: ArcadeColors.neonLime,
                onPressed: () {
                  _controller.resumeGame();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: ArcadeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.9,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: ArcadeTypography.microLabel),
          const SizedBox(height: 2.0),
          Text(
            value,
            style: ArcadeTypography.hudNumber.copyWith(
              color: color,
              fontSize: 15.0,
            ),
          ),
        ],
      ),
    );
  }
}
