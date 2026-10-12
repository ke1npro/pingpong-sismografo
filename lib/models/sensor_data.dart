import 'dart:math' as math;

/// Direcciones de bateo detectables mediante el acelerómetro
enum SwingDirection {
  left,
  right,
}

/// Estado del sismógrafo
enum SeismicState {
  /// Teléfono en reposo o estable (sin picos ni oscilaciones)
  stable,

  /// Oscilaciones leves y constantes detectadas (posible actividad sísmica regular)
  constantOscillation,

  /// Movimiento brusco o impacto repentino (pico demasiado alto)
  spikeDetected,

  /// Movimiento transitorio o ruido irregular que no constituye oscilación sostenida
  transientNoise,
}

/// Muestra puntual de aceleración 3D
class AccelSample {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;

  AccelSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
  }) : magnitude = math.sqrt(x * x + y * y + z * z);

  @override
  String toString() =>
      'AccelSample(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, mag: ${magnitude.toStringAsFixed(2)})';
}

/// Registro de un bateo detectado por el acelerómetro
class SwingEvent {
  final SwingDirection direction;
  final double intensity; // m/s^2
  final DateTime timestamp;
  final bool wasGraceBlocked; // Si ocurrió durante la ventana de 300ms

  SwingEvent({
    required this.direction,
    required this.intensity,
    required this.timestamp,
    this.wasGraceBlocked = false,
  });
}

/// Resultado del análisis sismográfico de una ventana de tiempo
class SeismicAnalysis {
  final SeismicState state;
  final double peakToPeak; // Amplitud pico a pico (m/s^2)
  final double maxSpike; // Mayor pico detectado en la ventana (m/s^2)
  final double dominantFrequencyHz; // Frecuencia estimada (Hz)
  final double currentMagnitude; // Magnitud dinámica instantánea
  final double oscillationDurationSeconds; // Duración de oscilación sostenida
  final double standardDeviation; // Desviación estándar de la señal
  final double zeroCrossingRate; // Cruces por cero por segundo
  final String statusDescription;
  final DateTime timestamp;

  const SeismicAnalysis({
    required this.state,
    required this.peakToPeak,
    required this.maxSpike,
    required this.dominantFrequencyHz,
    required this.currentMagnitude,
    required this.oscillationDurationSeconds,
    required this.standardDeviation,
    required this.zeroCrossingRate,
    required this.statusDescription,
    required this.timestamp,
  });

  bool get isStable => state == SeismicState.stable;
  bool get isConstantOscillation => state == SeismicState.constantOscillation;
  bool get isSpike => state == SeismicState.spikeDetected;
}

/// Entrada histórica en el registro del sismógrafo
class SeismicLogEntry {
  final DateTime timestamp;
  final SeismicState state;
  final String message;
  final double peakAmplitude;

  SeismicLogEntry({
    required this.timestamp,
    required this.state,
    required this.message,
    required this.peakAmplitude,
  });
}
