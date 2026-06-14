import '../models/models.dart';

/// Motor temporal basado en TPQN (Ticks Per Quarter Note)
/// Maneja toda la lógica de timing musical basada en ticks
class TicksEngine {
  static const int TPQN = 480; // Ticks Per Quarter Note (estándar MIDI)

  int _bpm = 120;
  late Stopwatch _timer;
  int _currentTick = 0;
  bool _isRunning = false;

  int get bpm => _bpm;
  int get currentTick => _currentTick;
  bool get isRunning => _isRunning;

  // Callback para notificar cambios de tick
  final List<Function(int)> _tickListeners = [];

  TicksEngine({int initialBpm = 120}) : _bpm = initialBpm {
    _validateBpm(_bpm);
    _timer = Stopwatch();
  }

  /// Establece el tempo en BPM
  /// Válido entre 30 y 300 BPM
  void setBpm(int newBpm) {
    _validateBpm(newBpm);
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
    return (ticks / TPQN) * getQuarterNoteDuration();
  }

  /// Convierte millisegundos a ticks
  int millisecondsToTicks(double ms) {
    final quarterNoteDuration = getQuarterNoteDuration();
    return (ms * TPQN / quarterNoteDuration).toInt();
  }

  /// Obtiene duración de una nota en ticks
  static int getNoteDurationTicks(NoteDuration duration) {
    return duration.getTicksAtTPQN480();
  }

  /// Comienza el reloj
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer.start();
  }

  /// Pausa el reloj
  void pause() {
    if (!_isRunning) return;
    _isRunning = false;
    _timer.stop();
  }

  /// Reinicia el reloj y el contador de ticks
  void reset() {
    _timer.reset();
    _currentTick = 0;
    _isRunning = false;
  }

  /// Reanuda desde pausa
  void resume() {
    if (_isRunning) return;
    _isRunning = true;
    _timer.start();
  }

  /// Actualiza el tick actual basado en tiempo transcurrido
  void update() {
    if (!_isRunning) return;

    final previousTick = _currentTick;
    _currentTick = millisecondsToTicks(_timer.elapsedMilliseconds.toDouble());

    // Notificar a listeners si hubo cambio
    if (_currentTick != previousTick) {
      for (var listener in _tickListeners) {
        listener(_currentTick);
      }
    }
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
  int get elapsedMilliseconds => _timer.elapsedMilliseconds;

  /// Información de debugeo
  String getDebugInfo() {
    return '''
    TicksEngine Debug:
    - BPM: $_bpm
    - Current Tick: $_currentTick
    - Quarter Note Duration: ${getQuarterNoteDuration().toStringAsFixed(2)}ms
    - Elapsed Time: ${_timer.elapsedMilliseconds}ms
    - Is Running: $_isRunning
    ''';
  }
}
