import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/spaceship_runner_controller.dart';
import '../theme/arcade_theme.dart';

/// Compact on-screen simulation dock providing:
/// 1. Continuous analog tilt slider $[-1.0, 1.0]$.
/// 2. Left/Right steer buttons with press-and-hold tactile gestures.
/// 3. Hardware keyboard listener (Arrow keys / A & D) for Web and Desktop navigation.
///
/// Guaranteed height <= 60px with robust overflow protection.
class RunnerSimulationDock extends StatefulWidget {
  final SpaceshipRunnerController controller;
  final double height;

  const RunnerSimulationDock({
    super.key,
    required this.controller,
    this.height = 56.0,
  });

  @override
  State<RunnerSimulationDock> createState() => _RunnerSimulationDockState();
}

class _RunnerSimulationDockState extends State<RunnerSimulationDock> {
  final FocusNode _focusNode = FocusNode();
  bool _isLeftPressed = false;
  bool _isRightPressed = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (isDown) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        widget.controller.setSimulatedTilt(-1.0);
        setState(() => _isLeftPressed = true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        widget.controller.setSimulatedTilt(1.0);
        setState(() => _isRightPressed = true);
      }
    } else if (isUp) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        widget.controller.clearSimulatedTilt();
        setState(() => _isLeftPressed = false);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        widget.controller.clearSimulatedTilt();
        setState(() => _isRightPressed = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double safeHeight = widget.height.clamp(48.0, 60.0);
    final double currentTilt = widget.controller.simulatedTiltX;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        height: safeHeight,
        constraints: BoxConstraints(maxHeight: safeHeight),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: ArcadeColors.surfaceDark.withValues(alpha: 0.96),
          border: const Border(
            top: BorderSide(
              color: ArcadeColors.borderSubtle,
              width: 1.0,
            ),
          ),
          boxShadow: ArcadeShadows.cardElevation(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: 360.0,
            height: safeHeight - 4.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left Steer Button (Press & Hold)
                _buildSteerButton(
                  icon: Icons.keyboard_arrow_left_rounded,
                  label: 'LEFT',
                  isPressed: _isLeftPressed,
                  onPressStart: () {
                    setState(() => _isLeftPressed = true);
                    widget.controller.setSimulatedTilt(-1.0);
                  },
                  onPressEnd: () {
                    setState(() => _isLeftPressed = false);
                    widget.controller.clearSimulatedTilt();
                  },
                ),

                const SizedBox(width: 8.0),

                // 2. Continuous Analog Tilt Slider with Center Notch
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TILT X SIM',
                              style: ArcadeTypography.microLabel,
                            ),
                            GestureDetector(
                              onTap: () => widget.controller.clearSimulatedTilt(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: ArcadeColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(
                                    color: ArcadeColors.borderSubtle,
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  '${currentTilt >= 0 ? '+' : ''}${currentTilt.toStringAsFixed(2)}',
                                  style: ArcadeTypography.hudNumberSmall.copyWith(
                                    color: ArcadeColors.neonCyan,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 24.0,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            activeTrackColor: ArcadeColors.neonCyan,
                            inactiveTrackColor: ArcadeColors.surfaceElevated,
                            thumbColor: ArcadeColors.neonCyan,
                            overlayColor: ArcadeColors.neonCyan.withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                          ),
                          child: Slider(
                            value: currentTilt.clamp(-1.0, 1.0),
                            min: -1.0,
                            max: 1.0,
                            onChanged: (val) {
                              if (val.abs() < 0.03) {
                                widget.controller.clearSimulatedTilt();
                              } else {
                                widget.controller.setSimulatedTilt(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8.0),

                // 3. Right Steer Button (Press & Hold)
                _buildSteerButton(
                  icon: Icons.keyboard_arrow_right_rounded,
                  label: 'RIGHT',
                  isPressed: _isRightPressed,
                  onPressStart: () {
                    setState(() => _isRightPressed = true);
                    widget.controller.setSimulatedTilt(1.0);
                  },
                  onPressEnd: () {
                    setState(() => _isRightPressed = false);
                    widget.controller.clearSimulatedTilt();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSteerButton({
    required IconData icon,
    required String label,
    required bool isPressed,
    required VoidCallback onPressStart,
    required VoidCallback onPressEnd,
  }) {
    final Color accentColor = ArcadeColors.neonCyan;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        onPressStart();
      },
      onTapUp: (_) => onPressEnd(),
      onTapCancel: () => onPressEnd(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 60.0,
        height: 38.0,
        decoration: BoxDecoration(
          color: isPressed
              ? accentColor.withValues(alpha: 0.35)
              : ArcadeColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isPressed
                ? accentColor
                : accentColor.withValues(alpha: 0.45),
            width: isPressed ? 1.4 : 1.0,
          ),
          boxShadow: isPressed
              ? ArcadeShadows.neonGlow(accentColor, intensity: 0.8)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: isPressed ? Colors.white : accentColor,
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isPressed ? Colors.white : ArcadeColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
