import '../core/core.dart';
import '../parsers/parsers.dart';

/// Sesión de juego que orquesta toda la lógica
class GameSession {
  // TODO: Orquestar TicksEngine
  // TODO: Orquestar Visual Engine
  // TODO: Orquestar ScoreEngine
  // TODO: Orquestar MetronomeController
  // TODO: Manejar game loop

  final TicksEngine ticksEngine;
  final ScoreEngine scoreEngine;
  final MusicScore? musicScore;

  late GameState _state;
  final List<Function(GameState)> _stateListeners = [];

  GameSession({
    required this.ticksEngine,
    required this.scoreEngine,
    this.musicScore,
  }) {
    _state = GameState.idle;
  }

  GameState get state => _state;

  /// Inicia la sesión de juego
  void start() {
    _changeState(GameState.playing);
    ticksEngine.start();
    // TODO: Iniciar metrónomo
    // TODO: Iniciar game loop
  }

  /// Pausa la sesión
  void pause() {
    _changeState(GameState.paused);
    ticksEngine.pause();
    // TODO: Pausar metrónomo
  }

  /// Reanuda la sesión
  void resume() {
    _changeState(GameState.playing);
    ticksEngine.resume();
    // TODO: Reanudar metrónomo
  }

  /// Detiene la sesión
  void stop() {
    _changeState(GameState.idle);
    ticksEngine.reset();
    // TODO: Detener metrónomo
  }

  /// Finaliza la sesión (mostrar resultados)
  void finish() {
    _changeState(GameState.finished);
    ticksEngine.pause();
    // TODO: Mostrar resumen de resultados
  }

  /// Reinicia la sesión
  void restart() {
    stop();
    scoreEngine.reset();
    _changeState(GameState.idle);
  }

  void _changeState(GameState newState) {
    _state = newState;
    for (var listener in _stateListeners) {
      listener(_state);
    }
  }

  void onStateChange(Function(GameState) callback) {
    _stateListeners.add(callback);
  }

  /// Maneja la entrada del usuario (presionar tecla/botón)
  void handleUserInput() {
    // TODO: Detectar nota más cercana a hit line
    // TODO: Calcular desviación
    // TODO: Determinar calidad de hit
    // TODO: Registrar en ScoreEngine
  }
}
