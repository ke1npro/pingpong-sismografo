import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/spaceship_runner_controller.dart';
import '../theme/arcade_theme.dart';

/// High-performance vector CustomPainter for Spaceship Runner.
///
/// Renders:
/// 1. Parallax starfield scrolling dynamically based on game distance.
/// 2. Neon playfield boundary guide rails.
/// 3. Player spaceship with banking rotation ($\theta = -v \cdot 10^\circ$), glowing thrusters,
///    and pulsing invulnerability force shield.
/// 4. Irregular rotating neon asteroids with crater details.
/// 5. Collision and thruster particle bursts.
class SpaceshipPainter extends CustomPainter {
  final SpaceshipRunnerController controller;

  // Cached starfield points for deterministic parallax rendering
  static final List<_StarData> _cachedStars = _generateStars(64);

  SpaceshipPainter({required this.controller}) : super(repaint: controller);

  static List<_StarData> _generateStars(int count) {
    final rand = math.Random(42); // Deterministic seed
    return List.generate(count, (_) {
      return _StarData(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        speedFactor: 0.3 + rand.nextDouble() * 0.9,
        size: 1.0 + rand.nextDouble() * 1.8,
        brightness: 0.35 + rand.nextDouble() * 0.65,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    if (width <= 0 || height <= 0) return;

    // 1. Draw Deep Space Parallax Starfield
    _paintStarfield(canvas, size);

    // 2. Draw Playfield Boundary Rails
    _paintBoundaryRails(canvas, size);

    // 3. Draw Asteroids
    _paintAsteroids(canvas, size);

    // 4. Draw Particles
    _paintParticles(canvas, size);

    // 5. Draw Player Spaceship
    _paintSpaceship(canvas, size);
  }

  void _paintStarfield(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final double dist = controller.distance;

    for (final star in _cachedStars) {
      final double sx = star.x * size.width;
      // Scroll vertically based on distance and individual layer speed
      final double sy = ((star.y + (dist * 0.0018 * star.speedFactor)) % 1.0) * size.height;

      final color = star.speedFactor > 0.8
          ? ArcadeColors.neonCyan.withValues(alpha: star.brightness * 0.85)
          : ArcadeColors.textPrimary.withValues(alpha: star.brightness * 0.45);

      paint.color = color;
      canvas.drawCircle(Offset(sx, sy), star.size, paint);
    }
  }

  void _paintBoundaryRails(Canvas canvas, Size size) {
    final double halfW = size.width / 2.0;
    const double bound = SpaceshipRunnerController.shipXBound;

    final double leftPx = halfW + (-bound * halfW);
    final double rightPx = halfW + (bound * halfW);

    final linePaint = Paint()
      ..color = ArcadeColors.neonCyan.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = ArcadeColors.neonCyan.withValues(alpha: 0.08)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Left and right boundary lines
    canvas.drawLine(Offset(leftPx, 0), Offset(leftPx, size.height), glowPaint);
    canvas.drawLine(Offset(leftPx, 0), Offset(leftPx, size.height), linePaint);

    canvas.drawLine(Offset(rightPx, 0), Offset(rightPx, size.height), glowPaint);
    canvas.drawLine(Offset(rightPx, 0), Offset(rightPx, size.height), linePaint);
  }

  void _paintAsteroids(Canvas canvas, Size size) {
    final double halfW = size.width / 2.0;

    for (final asteroid in controller.asteroids) {
      final double cx = halfW + (asteroid.x * halfW);
      final double cy = asteroid.y * size.height;
      final double rPx = asteroid.radius * halfW;

      // Off-screen culling
      if (cy + rPx < -20 || cy - rPx > size.height + 20) continue;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(asteroid.rotation);

      final path = Path();
      final int numPoints = asteroid.vertexRadiusOffsets.length;
      for (int i = 0; i < numPoints; i++) {
        final double angle = (i * 2 * math.pi) / numPoints;
        final double dist = rPx * asteroid.vertexRadiusOffsets[i];
        final double px = math.cos(angle) * dist;
        final double py = math.sin(angle) * dist;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();

      // Asteroid fill
      final fillPaint = Paint()
        ..color = ArcadeColors.surfaceElevated.withValues(alpha: 0.90)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Asteroid neon outline glow
      final glowPaint = Paint()
        ..color = ArcadeColors.neonAmber.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawPath(path, glowPaint);

      // Asteroid crisp neon border
      final borderPaint = Paint()
        ..color = ArcadeColors.neonAmber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawPath(path, borderPaint);

      // Inner crater detail
      final craterPaint = Paint()
        ..color = ArcadeColors.neonAmber.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawCircle(Offset(rPx * 0.25, -rPx * 0.15), rPx * 0.22, craterPaint);

      canvas.restore();
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    final double halfW = size.width / 2.0;

    for (final p in controller.particles) {
      final double px = halfW + (p.x * halfW);
      final double py = p.y * size.height;
      final double alpha = p.normalizedLife;
      final double pRadius = 1.8 + (1.0 - alpha) * 2.2;

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), pRadius, paint);
    }
  }

  void _paintSpaceship(Canvas canvas, Size size) {
    final double halfW = size.width / 2.0;
    final double shipCenterX = halfW + (controller.shipX * halfW);
    final double shipCenterY = SpaceshipRunnerController.shipY * size.height;

    // Banking angle proportional to ship horizontal velocity ($ -v \cdot 10^\circ $)
    // Max bank around +/- 20 degrees
    final double bankAngleRad = (-controller.shipVx * (10.0 * math.pi / 180.0)).clamp(-0.35, 0.35);

    canvas.save();
    canvas.translate(shipCenterX, shipCenterY);
    canvas.rotate(bankAngleRad);

    final double sScale = halfW * 0.11; // Ship visual size relative to half screen

    // 1. Thruster Glow and Flame
    _paintThruster(canvas, sScale);

    // 2. Main Ship Hull (Cyber Vector Polygon)
    _paintHull(canvas, sScale);

    // 3. Invulnerability Force Shield
    if (controller.isInvulnerable) {
      _paintShield(canvas, sScale);
    }

    canvas.restore();
  }

  void _paintThruster(Canvas canvas, double sScale) {
    final double flameFlicker = 0.75 + (math.Random().nextDouble() * 0.5);
    final double flameLength = sScale * 1.35 * flameFlicker;

    // Flame gradient
    final flamePath = Path()
      ..moveTo(-sScale * 0.28, sScale * 0.65)
      ..lineTo(0, sScale * 0.65 + flameLength)
      ..lineTo(sScale * 0.28, sScale * 0.65)
      ..close();

    final flamePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ArcadeColors.neonCyan,
          ArcadeColors.neonMagenta.withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(-sScale, sScale * 0.6, sScale * 2, flameLength))
      ..style = PaintingStyle.fill;

    canvas.drawPath(flamePath, flamePaint);

    // Inner core flame
    final corePath = Path()
      ..moveTo(-sScale * 0.14, sScale * 0.65)
      ..lineTo(0, sScale * 0.65 + (flameLength * 0.55))
      ..lineTo(sScale * 0.14, sScale * 0.65)
      ..close();

    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawPath(corePath, corePaint);
  }

  void _paintHull(Canvas canvas, double sScale) {
    // Spaceship outer delta-wing polygon
    final hullPath = Path()
      ..moveTo(0, -sScale * 1.3) // Nose tip
      ..lineTo(sScale * 0.35, -sScale * 0.2) // Cockpit forward angle
      ..lineTo(sScale * 0.95, sScale * 0.7) // Right wingtip
      ..lineTo(sScale * 0.55, sScale * 0.6) // Right wing intake
      ..lineTo(sScale * 0.25, sScale * 0.75) // Right thruster mount
      ..lineTo(0, sScale * 0.55) // Center stern notch
      ..lineTo(-sScale * 0.25, sScale * 0.75) // Left thruster mount
      ..lineTo(-sScale * 0.55, sScale * 0.6) // Left wing intake
      ..lineTo(-sScale * 0.95, sScale * 0.7) // Left wingtip
      ..lineTo(-sScale * 0.35, -sScale * 0.2) // Cockpit left angle
      ..close();

    // Dark cyber hull body
    final bodyPaint = Paint()
      ..color = ArcadeColors.surfaceDark
      ..style = PaintingStyle.fill;
    canvas.drawPath(hullPath, bodyPaint);

    // Neon Cyan glow underlay
    final glowPaint = Paint()
      ..color = ArcadeColors.neonCyan.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6;
    canvas.drawPath(hullPath, glowPaint);

    // Crisp Neon Cyan outline
    final outlinePaint = Paint()
      ..color = ArcadeColors.neonCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(hullPath, outlinePaint);

    // Cockpit Canopy (Neon Magenta accent)
    final canopyPath = Path()
      ..moveTo(0, -sScale * 0.85)
      ..lineTo(sScale * 0.20, -sScale * 0.1)
      ..lineTo(0, sScale * 0.2)
      ..lineTo(-sScale * 0.20, -sScale * 0.1)
      ..close();

    final canopyFill = Paint()
      ..color = ArcadeColors.neonMagenta.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(canopyPath, canopyFill);

    final canopyGlow = Paint()
      ..color = ArcadeColors.neonMagenta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(canopyPath, canopyGlow);
  }

  void _paintShield(Canvas canvas, double sScale) {
    // Pulsing shield circle based on remaining invulnerability timer
    final double pulse = 0.6 + (math.sin(controller.invulnerableTimer * 12.0) * 0.35);
    final double shieldRadius = sScale * 1.5;

    final shieldGlow = Paint()
      ..color = ArcadeColors.neonLime.withValues(alpha: (pulse * 0.35).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset.zero, shieldRadius, shieldGlow);

    final shieldBorder = Paint()
      ..color = ArcadeColors.neonLime.withValues(alpha: (pulse * 0.8).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, shieldRadius, shieldBorder);

    // Concentric inner ripple
    final rippleBorder = Paint()
      ..color = ArcadeColors.neonCyan.withValues(alpha: (pulse * 0.5).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(Offset.zero, shieldRadius * 0.8, rippleBorder);
  }

  @override
  bool shouldRepaint(covariant SpaceshipPainter oldDelegate) => true;
}

class _StarData {
  final double x;
  final double y;
  final double speedFactor;
  final double size;
  final double brightness;

  _StarData({
    required this.x,
    required this.y,
    required this.speedFactor,
    required this.size,
    required this.brightness,
  });
}
