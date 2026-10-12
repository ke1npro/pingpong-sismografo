import 'package:flutter/material.dart';

/// Represents the current lifecycle state of the spaceship runner minigame.
enum RunnerGameState {
  ready,
  playing,
  paused,
  gameOver,
}

/// Dynamic obstacle entity falling toward the player's spaceship.
///
/// Coordinates are normalized where:
/// - x: [-0.92, 0.92] (0.0 is center of playfield)
/// - y: [-0.25, 1.25] (-0.15 is spawn height above screen, 1.0 is bottom)
class Asteroid {
  final int id;
  double x;
  double y;
  final double radius;
  double rotation;
  final double rotationSpeed;
  final List<double> vertexRadiusOffsets;

  Asteroid({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.rotation,
    required this.rotationSpeed,
    required this.vertexRadiusOffsets,
  });

  /// Clone method for deterministic state inspection or test verification.
  Asteroid copyWith({
    int? id,
    double? x,
    double? y,
    double? radius,
    double? rotation,
    double? rotationSpeed,
    List<double>? vertexRadiusOffsets,
  }) {
    return Asteroid(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
      rotation: rotation ?? this.rotation,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      vertexRadiusOffsets: vertexRadiusOffsets ?? List.from(this.vertexRadiusOffsets),
    );
  }
}

/// Visual particle spark created during collisions or thruster trails.
class SpaceParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final int colorValue;

  SpaceParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  double get normalizedLife => (life / maxLife).clamp(0.0, 1.0);
}
