import '../core/core.dart';
import '../parsers/musicxml_parser.dart';

/// Sesión de juego que orquesta toda la lógica de detección de hits,
/// puntuación, combos y gestión del estado del juego.
class GameSession {
  final TicksEngine ticksEngine;
  final ScoreEngine scoreEngine;
  final MusicScore musicScore;
  final HitWindow hitWindow;

  // Estado mutable del juego
  Set<int> _hitNoteIndices = {};
  int _currentScore = 0;
  int _currentCombo = 0;
  int _maxCombo = 0;
  List<HitQuality> _hitHistory = [];
  GameState _state = GameState.idle;

  // Callbacks para notificar cambios de estado
  final List<void Function(GameState)> _stateListeners = [];
  final List<void Function()> _scoreListeners = [];
  final List<void Function()> _noteHitListeners = [];

  // Getter para el estado actual
  GameState get state => _state;

  // Getters para estadísticas (pueden exponerse a la UI)
  int get currentScore => _currentScore;
  int get currentCombo => _currentCombo;
  int get maxCombo => _maxCombo;
  Set<int> get hitNoteIndices => _hitNoteIndices;
  List<HitQuality> get hitHistory => _hitHistory;

  GameSession({
    required this.ticksEngine,
    required this.scoreEngine,
    required this.musicScore,
  }) : hitWindow = HitWindow(ticksEngine) {
    // Inicializar targetTick de cada nota (por defecto es absoluteTick)
    // En el futuro, se puede ajustar para anacrusa o compensaciones
    for (var note in musicScore.notes) {
      note.targetTick = note.absoluteTick;
    }
  }

  // ============================================================
  // MÉTODOS DE CONTROL DEL JUEGO
  // ============================================================

  void start() {
    if (_state == GameState.playing) return;
    _changeState(GameState.playing);
    ticksEngine.start();
    // Aquí se podría iniciar el metrónomo, pero se hará en otro módulo
  }

  void pause() {
    if (_state != GameState.playing) return;
    _changeState(GameState.paused);
    ticksEngine.pause();
  }

  void resume() {
    if (_state != GameState.paused) return;
    _changeState(GameState.playing);
    ticksEngine.resume();
  }

  void stop() {
    _changeState(GameState.idle);
    ticksEngine.reset();
    _resetGameState();
  }

  void restart() {
    stop();
    _resetGameState();
    _changeState(GameState.idle);
  }

  void finish() {
    _changeState(GameState.finished);
    ticksEngine.pause();
    // Notificar que el juego ha terminado (la UI mostrará resultados)
    _notifyScoreChanged();
  }

  // ============================================================
  // LÓGICA PRINCIPAL DE DETECCIÓN DE HITS
  // ============================================================

  /// Procesa la entrada del usuario (una nota tocada en el piano)
  void handleNoteInput(String pitch) {
    if (_state != GameState.playing) return;

    final currentTick = ticksEngine.currentTick;

    // 1. Buscar la nota más cercana (en tiempo) que aún no ha sido golpeada
    NoteModel? closestNote;
    int closestIndex = -1;
    int closestDeviation = 0; // en ticks
    int minDeviation = 1000000; // valor muy grande

    for (int i = 0; i < musicScore.notes.length; i++) {
      if (_hitNoteIndices.contains(i)) continue; // ya golpeada o perdida

      final note = musicScore.notes[i];
      final deviation = (note.targetTick - currentTick).abs();
      if (deviation < minDeviation) {
        minDeviation = deviation;
        closestNote = note;
        closestIndex = i;
        closestDeviation = note.targetTick - currentTick;
      }
    }

    // Si no hay nota candidata o está fuera de la ventana máxima, ignorar
    if (closestNote == null || closestIndex == -1) return;
    if (minDeviation > hitWindow.goodWindow) return; // fuera de tiempo

    // 2. Normalizar el pitch (comparar sin alteraciones accidentales)
    final expectedPitch = _normalizePitch(closestNote.pitch);
    final playedPitch = _normalizePitch(pitch);
    final isCorrectPitch = expectedPitch == playedPitch;

    // 3. Calcular la calidad del hit usando HitWindow
    final quality = hitWindow.getQuality(closestDeviation);
    if (quality == HitQuality.miss) {
      // Si falla, se marca como miss (no se añade a score)
      closestNote.markAsMissed();
      _hitNoteIndices.add(closestIndex);
      _currentCombo = 0;
      _hitHistory.add(HitQuality.miss);
      _notifyNoteHit();
      return;
    }

    // 4. Actualizar puntuación y combo si la nota es correcta
    if (isCorrectPitch) {
      // Sumar puntos según la calidad
      _currentScore += quality.getScore();
      _currentCombo++;
      if (_currentCombo > _maxCombo) _maxCombo = _currentCombo;

      // Marcar nota como golpeada
      closestNote.markAsHit(quality, currentTick);
    } else {
      // Nota incorrecta: se pierde combo, pero no se suman puntos
      _currentCombo = 0;
      closestNote.markAsMissed();
    }

    _hitNoteIndices.add(closestIndex);
    _hitHistory.add(quality);
    if (_hitHistory.length > 20) _hitHistory.removeAt(0); // limitar historial

    // 5. Notificar a los listeners
    _notifyScoreChanged();
    _notifyNoteHit();

    // 6. Si todas las notas han sido procesadas, finalizar
    if (_hitNoteIndices.length >= musicScore.notes.length) {
      finish();
    }
  }

  // ============================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ============================================================

  void _changeState(GameState newState) {
    if (_state == newState) return;
    _state = newState;
    for (var listener in _stateListeners) {
      listener(_state);
    }
  }

  void _resetGameState() {
    _hitNoteIndices.clear();
    _currentScore = 0;
    _currentCombo = 0;
    _maxCombo = 0;
    _hitHistory.clear();
    // Reiniciar estado de cada nota
    for (var note in musicScore.notes) {
      note.reset();
    }
    scoreEngine.reset();
    _notifyScoreChanged();
  }

  void _notifyScoreChanged() {
    for (var listener in _scoreListeners) {
      listener();
    }
  }

  void _notifyNoteHit() {
    for (var listener in _noteHitListeners) {
      listener();
    }
  }

  /// Normaliza el nombre de una nota a un formato estándar para comparación.
  /// Ej: "C#4" -> "C#4", "Db5" -> "C#5" (enarmonía), "B4" -> "B4"
  String _normalizePitch(String pitch) {
    var p = pitch.trim().toUpperCase();
    if (p.isEmpty) return p;
    // Reemplazar símbolos unicode por # y b
    p = p.replaceAll('♯', '#').replaceAll('♭', 'b');
    final match = RegExp(r'^([A-G])([#b]?)(\d+)$').firstMatch(p);
    if (match == null) return p;

    final note = match.group(1)!;
    final accidental = match.group(2) ?? '';
    final octave = int.parse(match.group(3)!);

    // Mapeo de notas a semitonos relativos a C
    const semitoneMap = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    var value = semitoneMap[note]! + (octave * 12);
    if (accidental == '#') value += 1;
    if (accidental == 'b') value -= 1;

    // Convertir de vuelta a nombre de nota con octava
    final normalizedOctave = value ~/ 12;
    final normalizedClass = value % 12;

    // Mapeo de clase a nombre (con sostenidos)
    const classNames = {
      0: 'C',
      1: 'C#',
      2: 'D',
      3: 'D#',
      4: 'E',
      5: 'F',
      6: 'F#',
      7: 'G',
      8: 'G#',
      9: 'A',
      10: 'A#',
      11: 'B',
    };

    return '${classNames[normalizedClass]}$normalizedOctave';
  }

  // ============================================================
  // REGISTRO DE LISTENERS
  // ============================================================

  void onStateChange(void Function(GameState) callback) {
    _stateListeners.add(callback);
  }

  void onScoreChange(void Function() callback) {
    _scoreListeners.add(callback);
  }

  void onNoteHit(void Function() callback) {
    _noteHitListeners.add(callback);
  }

  void removeStateListener(void Function(GameState) callback) {
    _stateListeners.remove(callback);
  }

  void removeScoreListener(void Function() callback) {
    _scoreListeners.remove(callback);
  }

  void removeNoteHitListener(void Function() callback) {
    _noteHitListeners.remove(callback);
  }

  // ============================================================
  // INFORMACIÓN DE ESTADO (para depuración)
  // ============================================================

  @override
  String toString() {
    return '''
    GameSession:
    - State: ${_state.displayName}
    - Score: $_currentScore
    - Combo: $_currentCombo / $_maxCombo
    - Hits: ${_hitNoteIndices.length}/${musicScore.notes.length}
    - Historial: ${_hitHistory.length} eventos
    ''';
  }
}