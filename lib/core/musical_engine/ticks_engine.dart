import '../models/models.dart';
import 'time_source.dart';

/// Motor temporal basado en un reloj monotónico y TPQN.
class TicksEngine {
  static const int tpnq = 480;
  static const int _microsecondsPerMinute = 60 * 1000000;

  final TimeSource _timeSource;
  int _bpm = 120;
  int _currentTick = 0;
  int _lastElapsedMicros = 0;
  int _tickRemainder = 0;

  /// Retardos medidos entre el evento musical y su observación en Dart.
  int audioLatencyMs = 0;
  int inputLatencyMs = 0;

  int get bpm => _bpm;
  int get currentTick => _currentTick;
  bool get isRunning => _timeSource.isRunning;

  // Callback para notificar cambios de tick
  final List<Function(int)> _tickListeners = [];

  TicksEngine({int initialBpm = 120, TimeSource? timeSource})
    : _bpm = initialBpm,
      _timeSource = timeSource ?? StopwatchTimeSource() {
    _validateBpm(_bpm);
  }

  /// Establece el tempo en BPM
  /// Válido entre 30 y 300 BPM
  void setBpm(int newBpm) {
    _validateBpm(newBpm);
    update();
    _bpm = newBpm;
  }

  /// Valida que el BPM esté en rango válido
  void _validateBpm(int bpm) {
    if (bpm < 30 || bpm > 300) {
      throw ArgumentError('BPM debe estar entre 30 y 300, recibido: $bpm');
    }
  }

  /// Duración de un quarter note en millisegundos
  /// Para 120 BPM: 60000 / 120 = 500ms
  double getQuarterNoteDuration() {
    return 60000 / _bpm;
  }

  /// Duración de un beat en millisegundos
  /// Para compas 4/4, beat = quarter note
  double getBeatDuration(int denominator) {
    // Para 4 (quarter note base), el beat es 1 quarter note
    // Para 8 (eighth note base), el beat es 2 eighth notes = 1 quarter note
    return getQuarterNoteDuration();
  }

  /// Convierte ticks a millisegundos
  double ticksToMilliseconds(int ticks) {
    return (ticks / tpnq) * getQuarterNoteDuration();
  }

  /// Convierte millisegundos a ticks
  int millisecondsToTicks(double ms) {
    final quarterNoteDuration = getQuarterNoteDuration();
    return (ms * tpnq / quarterNoteDuration).round();
  }

  /// Obtiene duración de una nota en ticks
  static int getNoteDurationTicks(NoteDuration duration) {
    return duration.getTicksAtTPQN480();
  }

  /// Comienza el reloj
  void start() {
    if (_timeSource.isRunning) return;
    _lastElapsedMicros = _timeSource.elapsedMicroseconds;
    _timeSource.start();
  }

  /// Pausa el reloj
  void pause() {
    if (!_timeSource.isRunning) return;
    update();
    _timeSource.stop();
  }

  /// Reinicia el reloj y el contador de ticks
  void reset() {
    _timeSource.reset();
    _lastElapsedMicros = 0;
    _tickRemainder = 0;
    _currentTick = 0;
  }

  /// Reanuda desde pausa
  void resume() {
    start();
  }

  /// Actualiza el tick actual basado en tiempo transcurrido
  void update() {
    if (!_timeSource.isRunning) return;

    final elapsedMicros = _timeSource.elapsedMicroseconds;
    final deltaMicros = elapsedMicros - _lastElapsedMicros;
    if (deltaMicros <= 0) return;
    _lastElapsedMicros = elapsedMicros;

    final tickNumerator = deltaMicros * tpnq * _bpm + _tickRemainder;
    final deltaTicks = tickNumerator ~/ _microsecondsPerMinute;
    _tickRemainder = tickNumerator % _microsecondsPerMinute;
    if (deltaTicks == 0) return;

    final previousTick = _currentTick;
    _currentTick += deltaTicks;

    // Notificar a listeners si hubo cambio
    if (_currentTick != previousTick) {
      for (var listener in _tickListeners) {
        listener(_currentTick);
      }
    }
  }

  /// Tick corregido para comparar una entrada con el evento percibido.
  int get tickForInput {
    final correctionMs = audioLatencyMs + inputLatencyMs;
    return _currentTick - millisecondsToTicks(correctionMs.toDouble());
  }

  /// Agrega un listener que se ejecuta cuando cambia el tick
  void onTickChange(Function(int) callback) {
    _tickListeners.add(callback);
  }

  /// Remueve un listener
  void removeTickListener(Function(int) callback) {
    _tickListeners.remove(callback);
  }

  /// Retorna el tiempo transcurrido en millisegundos
  int get elapsedMilliseconds => _timeSource.elapsedMicroseconds ~/ 1000;

  /// Información de debugeo
  String getDebugInfo() {
    return '''
    TicksEngine Debug:
    - BPM: $_bpm
    - Current Tick: $_currentTick
    - Quarter Note Duration: ${getQuarterNoteDuration().toStringAsFixed(2)}ms
    - Elapsed Time: ${elapsedMilliseconds}ms
    - Is Running: ${_timeSource.isRunning}
    - Audio latency: ${audioLatencyMs}ms
    - Input latency: ${inputLatencyMs}ms
    ''';
  }
}
