import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sensor_data.dart';

/// Servicio singleton para captura, filtrado, detección de bateos con grace time
/// y análisis sismográfico de estabilidad y oscilaciones constantes.
class SensorService extends ChangeNotifier {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal() {
    _initSensors();
  }

  // --- Subscripciones de Sensores ---
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _simulationTimer;
  Timer? _fallbackCheckTimer;

  // --- Estado del Acelerómetro Crudo y Dinámico ---
  double _rawX = 0.0;
  double _rawY = 0.0;
  double _rawZ = 0.0;
  double _dynamicMagnitude = 0.0;
  bool _isRealSensorAvailable = false;
  bool _isSimulating = false;

  // Filtro pasa-altos adaptable para gravedad
  double _gravX = 0.0;
  double _gravY = 0.0;
  double _gravZ = 9.8;
  int _sensorEventsReceived = 0;
  int _userAccelEventsReceived = 0;
  int _accelEventsReceived = 0;
  double _tiltX = 0.0;

  // --- Configuración y Detección de Bateo (Ping Pong) ---
  // Umbral calibrado: 6.2 m/s^2 es natural y sensible para muñecazos y abanicos normales
  double _swingThreshold = 6.2;
  int _gracePeriodMs = 300; // 300ms requeridos por especificación
  DateTime? _lastAcceptedSwingTime;
  SwingDirection? _lastSwingDirection;
  double _lastSwingIntensity = 0.0;
  int _blockedRecoilsCount = 0;
  bool _graceRecoilHandledInCurrentWindow = false;

  // Stream controller para eventos de bateo
  final _swingStreamController = StreamController<SwingEvent>.broadcast();
  Stream<SwingEvent> get swingStream => _swingStreamController.stream;

  // --- Control de Tasa de Notificaciones (Throttling a ~30 FPS para evitar lag) ---
  DateTime _lastNotifyTime = DateTime.now();
  static const int _notifyThrottleMs = 33; // 30 FPS máximo para rebuilds de UI

  // --- Configuración y Detección de Sismógrafo ---
  static const int _bufferCapacity = 140; // ~2.5 segundos de muestras a ~50Hz
  final ListQueue<AccelSample> _samplesBuffer = ListQueue<AccelSample>(_bufferCapacity);

  // Umbrales sismográficos
  // Umbral de reposo: por defecto 0.11 m/s² para tolerar la variación normal de 0.05 a 0.10 m/s²
  double _stabilityThreshold = 0.11;
  final double _maxSlightThreshold = 1.90; // Amplitud máxima para considerarse "leve" (m/s^2)
  double _spikeThreshold = 2.40; // Por encima es un impacto/pico brusco (m/s^2)
  final int _minConsecutiveOscillationFrames = 15; // Cuadros continuos para confirmar constancia (~0.3s)

  int _consecutiveOscillationFrames = 0;
  DateTime? _oscillationStartTime;
  double _oscillationDurationSeconds = 0.0;
  SeismicState _currentSeismicState = SeismicState.stable;
  String _seismicStatusDescription = 'Teléfono Estable (Sin Perturbaciones)';

  // Registro histórico de eventos sísmicos
  final List<SeismicLogEntry> _seismicLogs = [];

  // Métrica actual de análisis sísmico
  SeismicAnalysis _latestAnalysis = SeismicAnalysis(
    state: SeismicState.stable,
    peakToPeak: 0.0,
    maxSpike: 0.0,
    dominantFrequencyHz: 0.0,
    currentMagnitude: 0.0,
    oscillationDurationSeconds: 0.0,
    standardDeviation: 0.0,
    zeroCrossingRate: 0.0,
    statusDescription: 'Inicializando sensores...',
    timestamp: DateTime.now(),
  );

  // --- Getters Públicos ---
  double get x => _rawX;
  double get y => _rawY;
  double get z => _rawZ;
  double get dynamicMagnitude => _dynamicMagnitude;
  bool get isRealSensorAvailable => _isRealSensorAvailable;
  bool get isSimulating => _isSimulating;

  double get swingThreshold => _swingThreshold;
  set swingThreshold(double value) {
    _swingThreshold = value;
    _maybeNotifyListeners(force: true);
  }

  int get gracePeriodMs => _gracePeriodMs;
  set gracePeriodMs(int value) {
    _gracePeriodMs = value;
    _maybeNotifyListeners(force: true);
  }

  double get stabilityThreshold => _stabilityThreshold;
  set stabilityThreshold(double val) {
    _stabilityThreshold = val;
    _maybeNotifyListeners(force: true);
  }

  double get spikeThreshold => _spikeThreshold;
  set spikeThreshold(double val) {
    _spikeThreshold = val;
    _maybeNotifyListeners(force: true);
  }

  bool get isGracePeriodActive {
    if (_lastAcceptedSwingTime == null) return false;
    final elapsed = DateTime.now().difference(_lastAcceptedSwingTime!).inMilliseconds;
    return elapsed < _gracePeriodMs;
  }

  double get gracePeriodRemainingRatio {
    if (_lastAcceptedSwingTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_lastAcceptedSwingTime!).inMilliseconds;
    if (elapsed >= _gracePeriodMs) return 0.0;
    return 1.0 - (elapsed / _gracePeriodMs);
  }

  int get gracePeriodRemainingMs {
    if (_lastAcceptedSwingTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastAcceptedSwingTime!).inMilliseconds;
    final remaining = _gracePeriodMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  SwingDirection? get lastSwingDirection => _lastSwingDirection;
  double get lastSwingIntensity => _lastSwingIntensity;
  int get blockedRecoilsCount => _blockedRecoilsCount;

  SeismicState get currentSeismicState => _currentSeismicState;
  String get seismicStatusDescription => _seismicStatusDescription;
  SeismicAnalysis get latestAnalysis => _latestAnalysis;
  List<AccelSample> get samplesList => _samplesBuffer.toList();
  List<SeismicLogEntry> get seismicLogs => List.unmodifiable(_seismicLogs);

  // --- Inicialización y Escucha de Sensores con Respaldo Automático ---
  void _initSensors() {
    // 1. Escuchar acelerómetro crudo (incluye gravedad estática g ≈ 9.8 m/s²)
    // Esencial para la inclinación continua (tilt) del teléfono en Spaceship Runner y Ping Pong
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          _isRealSensorAvailable = true;
          _accelEventsReceived++;
          _sensorEventsReceived++;
          if (!_isSimulating) {
            _processAccelerometerEvent(event);
          }
        },
        onError: (err) {
          debugPrint('accelerometerEventStream error: $err');
        },
      );
    } catch (_) {}

    // 2. Escuchar acelerómetro de usuario (aceleración dinámica lineal sin gravedad)
    // Esencial para la detección de bateos rápidos en Ping Pong y para análisis sismográfico
    try {
      _userAccelSub = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (UserAccelerometerEvent event) {
          _isRealSensorAvailable = true;
          _userAccelEventsReceived++;
          _sensorEventsReceived++;
          if (!_isSimulating) {
            _processSensorSample(event.x, event.y, event.z);
          }
        },
        onError: (err) {
          debugPrint('userAccelerometerEventStream error: $err, fallback activado');
        },
      );
    } catch (_) {}

    // Verificar si el flujo de userAccelerometer no emite nada tras 600ms
    _fallbackCheckTimer = Timer(const Duration(milliseconds: 600), () {
      if (_sensorEventsReceived == 0 && !_isSimulating) {
        _activateAccelerometerFallback();
      }
    });
  }

  void _activateAccelerometerFallback() {
    if (_accelSub != null) return;
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          _isRealSensorAvailable = true;
          _accelEventsReceived++;
          _sensorEventsReceived++;
          if (!_isSimulating) {
            _processAccelerometerEvent(event);
          }
        },
        onError: (err) {
          debugPrint('Acelerómetro no disponible físicamente: $err');
        },
      );
    } catch (_) {}
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    // Filtro pasa-altos adaptable para gravedad
    _gravX = 0.88 * _gravX + 0.12 * event.x;
    _gravY = 0.88 * _gravY + 0.12 * event.y;
    _gravZ = 0.88 * _gravZ + 0.12 * event.z;

    // En coordenadas de Android en modo portrait:
    // Al inclinar el teléfono hacia la derecha, el componente de reacción normal
    // de la gravedad proyecta un valor negativo en el eje X (-4 a -7 m/s²).
    // Invertir el signo (-event.x) mapea la inclinación a la derecha a valores positivos.
    final targetTiltX = -event.x;
    // Suavizado suave (filtro paso bajo exponencial) para estabilidad sin retraso perceptible
    _tiltX = 0.70 * _tiltX + 0.30 * targetTiltX;

    // Si userAccelerometerEventStream no está emitiendo en este dispositivo,
    // usamos la aceleración dinámica calculada a partir del filtro pasa-altos
    if (_userAccelEventsReceived == 0) {
      final dynX = event.x - _gravX;
      final dynY = event.y - _gravY;
      final dynZ = event.z - _gravZ;
      _processSensorSample(dynX, dynY, dynZ);
    } else {
      // Si userAccelerometer está activo, _rawX refleja la inclinación física para Spaceship Runner
      _rawX = _tiltX;
      _maybeNotifyListeners();
    }
  }

  // --- Procesamiento Central de Cada Muestra ---
  void _processSensorSample(double xVal, double yVal, double zVal) {
    final now = DateTime.now();
    // Si tenemos acelerómetro crudo activo, _rawX utiliza la inclinación física real _tiltX
    if (_accelEventsReceived > 0 && !_isSimulating) {
      _rawX = _tiltX;
    } else {
      _rawX = xVal;
    }
    _rawY = yVal;
    _rawZ = zVal;

    final sample = AccelSample(
      timestamp: now,
      x: xVal,
      y: yVal,
      z: zVal,
    );
    _dynamicMagnitude = sample.magnitude;

    // Actualizar buffer circular para el sismógrafo
    if (_samplesBuffer.length >= _bufferCapacity) {
      _samplesBuffer.removeFirst();
    }
    _samplesBuffer.add(sample);

    // 1. Evaluar detección de bateo (Ping Pong)
    final bool swingTriggered = _checkSwingDetection(xVal, now);

    // 2. Evaluar sismógrafo (Estabilidad y Oscilaciones)
    final bool seismicChanged = _evaluateSeismograph(now);

    // Notificar a la UI con control de tasa (throttling) para asegurar 60 FPS fluidos
    _maybeNotifyListeners(force: swingTriggered || seismicChanged);
  }

  void _maybeNotifyListeners({bool force = false}) {
    final now = DateTime.now();
    if (force || now.difference(_lastNotifyTime).inMilliseconds >= _notifyThrottleMs) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  // --- 1. Lógica de Bateo y Grace Time de 300ms ---
  bool _checkSwingDetection(double xAcc, DateTime now) {
    final absX = xAcc.abs();

    if (absX >= _swingThreshold) {
      final direction = xAcc > 0 ? SwingDirection.right : SwingDirection.left;

      // Verificación de Grace Period (300ms)
      if (isGracePeriodActive) {
        // Ignorar swing de regreso o freno del teléfono durante los 300ms
        // Solo registrar 1 evento por cada ventana de grace period para no saturar la UI
        if (!_graceRecoilHandledInCurrentWindow) {
          _graceRecoilHandledInCurrentWindow = true;
          _blockedRecoilsCount++;
          _swingStreamController.add(
            SwingEvent(
              direction: direction,
              intensity: absX,
              timestamp: now,
              wasGraceBlocked: true,
            ),
          );
        }
        return false;
      }

      // Swing válido y aceptado
      _lastAcceptedSwingTime = now;
      _lastSwingDirection = direction;
      _lastSwingIntensity = absX;
      _graceRecoilHandledInCurrentWindow = false;

      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

      _swingStreamController.add(
        SwingEvent(
          direction: direction,
          intensity: absX,
          timestamp: now,
          wasGraceBlocked: false,
        ),
      );
      return true;
    }
    return false;
  }

  /// Disparar swing manualmente (para simulaciones y pruebas directas)
  void triggerManualSwing(SwingDirection direction, {double intensity = 12.0}) {
    final now = DateTime.now();
    final xVal = direction == SwingDirection.right ? intensity : -intensity;
    _checkSwingDetection(xVal, now);
    _maybeNotifyListeners(force: true);
  }

  /// Calibra automáticamente el umbral de reposo midiendo el ruido basal del sensor en reposo
  double autoCalibrateRestingThreshold() {
    if (_samplesBuffer.length < 10) return _stabilityThreshold;
    double maxMag = 0.0;
    double minMag = double.infinity;
    for (final s in _samplesBuffer) {
      final m = s.magnitude;
      if (m > maxMag) maxMag = m;
      if (m < minMag) minMag = m;
    }
    final measuredNoise = maxMag - minMag;
    // Asigna el umbral con un margen del 20% sobre el ruido medido, mínimo 0.05
    final double calibrated = (measuredNoise * 1.20).clamp(0.05, 0.35);
    _stabilityThreshold = (calibrated * 100).round() / 100;
    _maybeNotifyListeners(force: true);
    return _stabilityThreshold;
  }

  // --- 2. Lógica del Sismógrafo (Estabilidad y Oscilaciones Leves Constantes) ---
  bool _evaluateSeismograph(DateTime now) {
    if (_samplesBuffer.length < 20) return false;

    // Calcular estadísticas en la ventana rodante
    double maxMag = 0.0;
    double minMag = double.infinity;
    double sum = 0.0;
    final List<double> mags = [];

    for (final s in _samplesBuffer) {
      final m = s.magnitude;
      mags.add(m);
      if (m > maxMag) maxMag = m;
      if (m < minMag) minMag = m;
      sum += m;
    }

    final double mean = sum / mags.length;
    final double peakToPeak = maxMag - minMag;

    // Desviación estándar
    double varSum = 0.0;
    for (final m in mags) {
      varSum += (m - mean) * (m - mean);
    }
    final double stdDev = math.sqrt(varSum / mags.length);

    // Contar cruces por cero relativos a la media para estimar frecuencia
    int zeroCrossings = 0;
    for (int i = 1; i < mags.length; i++) {
      final prev = mags[i - 1] - mean;
      final curr = mags[i] - mean;
      if ((prev < 0 && curr >= 0) || (prev > 0 && curr <= 0)) {
        zeroCrossings++;
      }
    }

    // Duración de la ventana en segundos
    final windowDurationSec = _samplesBuffer.last.timestamp
            .difference(_samplesBuffer.first.timestamp)
            .inMilliseconds /
        1000.0;
    final double freqHz = windowDurationSec > 0.3
        ? (zeroCrossings / (2.0 * windowDurationSec)).clamp(0.0, 20.0)
        : 0.0;

    SeismicState newState;
    String newDesc;

    // REGLA 1: Picos altos (Perturbación brusca / impacto repentino)
    // "nada de picos demasiado altos"
    if (maxMag > _spikeThreshold) {
      newState = SeismicState.spikeDetected;
      newDesc = '¡Perturbación Brusca! Pico de ${maxMag.toStringAsFixed(2)} m/s² detectado';
      _consecutiveOscillationFrames = 0;
      _oscillationStartTime = null;
      _oscillationDurationSeconds = 0.0;
    }
    // REGLA 2: Estable (En reposo normal, tolera variación de 0.05 a 0.10 m/s^2 según _stabilityThreshold)
    // "que detecte sí el teléfono está estable (nada de picos demasiado altos)"
    else if (peakToPeak <= _stabilityThreshold && maxMag <= (_stabilityThreshold + 0.12)) {
      newState = SeismicState.stable;
      newDesc = 'Estable (En reposo: var ${peakToPeak.toStringAsFixed(2)} ≤ ${_stabilityThreshold.toStringAsFixed(2)} m/s²)';
      _consecutiveOscillationFrames = 0;
      _oscillationStartTime = null;
      _oscillationDurationSeconds = 0.0;
    }
    // REGLA 3: Oscilaciones leves pero constantes (por encima de la variación de reposo)
    // "y detecte sí hay unas oscilaciones leves pero constantes"
    else if (peakToPeak > _stabilityThreshold &&
        peakToPeak <= _maxSlightThreshold &&
        maxMag <= _spikeThreshold &&
        freqHz >= 0.8 &&
        freqHz <= 8.5) {
      _consecutiveOscillationFrames++;

      if (_consecutiveOscillationFrames >= _minConsecutiveOscillationFrames) {
        newState = SeismicState.constantOscillation;
        _oscillationStartTime ??= now;
        _oscillationDurationSeconds =
            now.difference(_oscillationStartTime!).inMilliseconds / 1000.0;
        newDesc =
            '¡Actividad Sísmica! Oscilación de ${freqHz.toStringAsFixed(1)} Hz (P-P: ${peakToPeak.toStringAsFixed(2)} m/s²)';
      } else {
        newState = SeismicState.transientNoise;
        newDesc = 'Verificando constancia de oscilación...';
      }
    } else {
      newState = SeismicState.transientNoise;
      newDesc = 'Ruido transitorio o ajuste';
      if (_consecutiveOscillationFrames > 0) _consecutiveOscillationFrames--;
      if (_consecutiveOscillationFrames == 0) {
        _oscillationStartTime = null;
        _oscillationDurationSeconds = 0.0;
      }
    }

    final bool stateChanged = newState != _currentSeismicState;
    if (stateChanged) {
      _addSeismicLog(newState, newDesc, maxMag);
    }

    _currentSeismicState = newState;
    _seismicStatusDescription = newDesc;

    _latestAnalysis = SeismicAnalysis(
      state: newState,
      peakToPeak: peakToPeak,
      maxSpike: maxMag,
      dominantFrequencyHz: freqHz,
      currentMagnitude: _dynamicMagnitude,
      oscillationDurationSeconds: _oscillationDurationSeconds,
      standardDeviation: stdDev,
      zeroCrossingRate: zeroCrossings / (windowDurationSec > 0 ? windowDurationSec : 1.0),
      statusDescription: newDesc,
      timestamp: now,
    );

    return stateChanged;
  }

  void _addSeismicLog(SeismicState state, String message, double peak) {
    if (state == SeismicState.transientNoise) return;
    final entry = SeismicLogEntry(
      timestamp: DateTime.now(),
      state: state,
      message: message,
      peakAmplitude: peak,
    );
    _seismicLogs.insert(0, entry);
    if (_seismicLogs.length > 50) {
      _seismicLogs.removeLast();
    }
  }

  void clearLogs() {
    _seismicLogs.clear();
    _maybeNotifyListeners(force: true);
  }

  // --- 3. Simuladores de Señal para Pruebas en Desktop y Verificación ---
  double _simPhase = 0.0;
  String _simMode = 'none';

  void startSimulation(String mode) {
    _isSimulating = true;
    _simMode = mode;
    _simulationTimer?.cancel();

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _simPhase += 0.15;
      double simX = 0.0;
      double simY = 0.0;
      double simZ = 0.0;

      final randomJitter = (math.Random().nextDouble() - 0.5) * 0.04;

      if (_simMode == 'stable') {
        // Variación normal de reposo entre 0.05 y 0.09 m/s² tal como ocurre físicamente
        final restingJitter = (math.Random().nextDouble() - 0.5) * 0.07;
        simX = restingJitter;
        simY = restingJitter * 0.6;
        simZ = restingJitter * 0.4;
      } else if (_simMode == 'constant_oscillation') {
        final sineWave = math.sin(_simPhase * 1.5) * 0.70;
        simX = sineWave + randomJitter;
        simY = (math.cos(_simPhase * 1.5) * 0.40) + randomJitter;
        simZ = randomJitter;
      } else if (_simMode == 'spike') {
        simX = (math.Random().nextDouble() > 0.5 ? 1 : -1) * 3.8;
        simY = 2.1;
        simZ = -1.9;
        _simMode = 'stable';
      }

      _processSensorSample(simX, simY, simZ);
    });
    _maybeNotifyListeners(force: true);
  }

  void stopSimulation() {
    _isSimulating = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _maybeNotifyListeners(force: true);
  }

  @override
  void dispose() {
    _userAccelSub?.cancel();
    _accelSub?.cancel();
    _simulationTimer?.cancel();
    _fallbackCheckTimer?.cancel();
    _swingStreamController.close();
    super.dispose();
  }
}
