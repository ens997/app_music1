import 'dart:async';

import '../core/core.dart';
import '../parsers/musicxml_parser.dart';
import '../audio/metronome_audio_output.dart';
import 'metronome_controller.dart';

/// Sesión de juego que orquesta toda la lógica de detección de hits,
/// puntuación, combos y gestión del estado del juego.
class GameSession {
  final TicksEngine ticksEngine;
  final ScoreEngine scoreEngine;
  final MusicScore musicScore;
  final HitWindow hitWindow;
  late final MetronomeController metronomeController;

  // Estado mutable del juego
  Set<int> _hitNoteIndices = {};
  List<HitQuality> _hitHistory = [];
  GameState _state = GameState.idle;
  late final bool _hasPlayableNotes;
  late final int _completionTick;
  late final List<int> _playableNoteIndices;
  int _nextPlayablePosition = 0;

  // Callbacks para notificar cambios de estado
  final List<void Function(GameState)> _stateListeners = [];
  final List<void Function()> _scoreListeners = [];
  final List<void Function()> _noteHitListeners = [];
  final List<
    void Function(int noteIndex, HitQuality quality, bool isCorrectPitch)
  >
  _noteFeedbackListeners = [];

  // Getter para el estado actual
  GameState get state => _state;
  bool get isFinished => _state == GameState.finished;

  // Getters para estadísticas (pueden exponerse a la UI)
  int get currentScore => scoreEngine.totalScore;
  int get currentCombo => scoreEngine.combo;
  int get maxCombo => scoreEngine.maxCombo;
  Set<int> get hitNoteIndices => _hitNoteIndices;
  List<HitQuality> get hitHistory => _hitHistory;

  bool get hasPlayableNotes => _hasPlayableNotes;

  int get completionTick => _completionTick;

  GameSession({
    required this.ticksEngine,
    required this.scoreEngine,
    required this.musicScore,
    MetronomeAudioOutput? audioService,
  }) : hitWindow = HitWindow(ticksEngine) {
    // Inicializar targetTick de cada nota (por defecto es absoluteTick)
    // En el futuro, se puede ajustar para anacrusa o compensaciones
    for (var note in musicScore.notes) {
      note.targetTick = note.absoluteTick;
    }

    // Inicializar metrónomo con la métrica del MusicXML
    final audioSvc = audioService ?? const SilentMetronomeAudioOutput();
    metronomeController = MetronomeController(
      ticksEngine: ticksEngine,
      timeSignature: musicScore.timeSignature,
      audioService: audioSvc,
    );

    _hasPlayableNotes = musicScore.notes.any((note) => !note.isRest);
    _playableNoteIndices = [
      for (var i = 0; i < musicScore.notes.length; i++)
        if (!musicScore.notes[i].isRest) i,
    ];
    if (_hasPlayableNotes) {
      final lastPlayableNote = musicScore.notes.lastWhere(
        (note) => !note.isRest,
      );
      _completionTick = lastPlayableNote.targetTick + hitWindow.goodWindow;
    } else {
      _completionTick = 0;
    }
  }

  // ============================================================
  // MÉTODOS DE CONTROL DEL JUEGO
  // ============================================================

  void start() {
    if (_state == GameState.playing) return;
    _changeState(GameState.playing);
    ticksEngine.start();
    metronomeController.start();
  }

  void pause() {
    if (_state != GameState.playing) return;
    _changeState(GameState.paused);
    ticksEngine.pause();
    metronomeController.stop();
  }

  void resume() {
    if (_state != GameState.paused) return;
    _changeState(GameState.playing);
    ticksEngine.resume();
    metronomeController.start();
  }

  void stop() {
    _changeState(GameState.idle);
    ticksEngine.reset();
    metronomeController.stop();
    _resetGameState();
  }

  void restart() {
    stop();
    _resetGameState();
    _changeState(GameState.idle);
  }

  void finish() {
    if (isFinished) return;
    _markRemainingNotesAsMissed();
    _changeState(GameState.finished);
    ticksEngine.pause();
    metronomeController.stop();
    // Notificar que el juego ha terminado (la UI mostrará resultados)
    _notifyScoreChanged();
    _notifyNoteHit();
  }

  /// Actualiza el estado del juego
  /// Se debe llamar cada frame del game loop (aproximadamente 60fps)
  void update() {
    ticksEngine.update();
    unawaited(metronomeController.update());
  }

  // ============================================================
  // LÓGICA PRINCIPAL DE DETECCIÓN DE HITS
  // ============================================================

  /// Procesa la entrada del usuario (una nota tocada en el piano)
  bool handleNoteInput(String pitch) {
    if (_state != GameState.playing) return false;

    ticksEngine.update();
    final currentTick = ticksEngine.tickForInput;

    // 1. Buscar la nota más cercana (en tiempo) que aún no ha sido golpeada
    NoteModel? closestNote;
    int closestIndex = -1;
    int closestDeviation = 0; // en ticks
    int minDeviation = 1000000; // valor muy grande

    _advancePlayableCursor();
    final candidateStart = _nextPlayablePosition;
    for (
      int position = candidateStart;
      position < _playableNoteIndices.length;
      position++
    ) {
      final i = _playableNoteIndices[position];
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
    if (closestNote == null || closestIndex == -1) return false;
    if (minDeviation > hitWindow.goodWindow) return false; // fuera de tiempo

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
      _advancePlayableCursor();
      scoreEngine.recordMiss();
      _appendHitHistory(HitQuality.miss);
      _notifyNoteHit();
      _notifyNoteFeedback(closestIndex, HitQuality.miss, isCorrectPitch);
      if (_nextPlayablePosition >= _playableNoteIndices.length) {
        finish();
      }
      return false;
    }

    bool success = false;

    // 4. Actualizar puntuación y combo si la nota es correcta
    if (isCorrectPitch) {
      // Marcar nota como golpeada
      closestNote.markAsHit(quality, currentTick);
      scoreEngine.recordHit(quality);
      success = true;
    } else {
      // Nota incorrecta: se pierde combo, pero no se suman puntos
      closestNote.markAsMissed();
      scoreEngine.recordMiss();
    }

    _hitNoteIndices.add(closestIndex);
    _advancePlayableCursor();
    scoreEngine.recordDeviation(closestDeviation);
    _appendHitHistory(isCorrectPitch ? quality : HitQuality.miss);

    // 5. Notificar a los listeners
    _notifyScoreChanged();
    _notifyNoteHit();
    _notifyNoteFeedback(closestIndex, quality, isCorrectPitch);

    // 6. Si todas las notas han sido procesadas, finalizar
    if (_nextPlayablePosition >= _playableNoteIndices.length) {
      finish();
    }

    return success;
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

  void _advancePlayableCursor() {
    while (_nextPlayablePosition < _playableNoteIndices.length &&
        _hitNoteIndices.contains(_playableNoteIndices[_nextPlayablePosition])) {
      _nextPlayablePosition++;
    }
  }

  /// Marca como falladas las notas reproducibles que no se resolvieron antes
  /// de terminar la partida, para cerrar las estadísticas de forma consistente.
  void _markRemainingNotesAsMissed() {
    for (
      var position = _nextPlayablePosition;
      position < _playableNoteIndices.length;
      position++
    ) {
      final noteIndex = _playableNoteIndices[position];
      if (_hitNoteIndices.contains(noteIndex)) continue;

      musicScore.notes[noteIndex].markAsMissed();
      _hitNoteIndices.add(noteIndex);
      scoreEngine.recordMiss();
      _appendHitHistory(HitQuality.miss);
      _notifyNoteFeedback(noteIndex, HitQuality.miss, false);
    }
    _advancePlayableCursor();
  }

  void _appendHitHistory(HitQuality quality) {
    _hitHistory.add(quality);
    if (_hitHistory.length > 20) _hitHistory.removeAt(0);
  }

  void _resetGameState() {
    _hitNoteIndices.clear();
    _nextPlayablePosition = 0;
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

  void _notifyNoteFeedback(
    int noteIndex,
    HitQuality quality,
    bool isCorrectPitch,
  ) {
    for (var listener in _noteFeedbackListeners) {
      listener(noteIndex, quality, isCorrectPitch);
    }
  }

  String _normalizePitch(String pitch) => PitchUtils.normalize(pitch);

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

  /// Notifica el resultado de cada golpe (índice, calidad y acierto de tono)
  /// para alimentar feedback visual inmediato sin acoplar GameSession a la UI.
  void onNoteFeedback(
    void Function(int noteIndex, HitQuality quality, bool isCorrectPitch)
    callback,
  ) {
    _noteFeedbackListeners.add(callback);
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

  void removeNoteFeedbackListener(
    void Function(int noteIndex, HitQuality quality, bool isCorrectPitch)
    callback,
  ) {
    _noteFeedbackListeners.remove(callback);
  }

  // ============================================================
  // INFORMACIÓN DE ESTADO (para depuración)
  // ============================================================

  @override
  String toString() {
    return '''
    GameSession:
    - State: ${_state.displayName}
    - Score: $currentScore
    - Combo: $currentCombo / $maxCombo
    - Hits: ${_hitNoteIndices.length}/${musicScore.notes.length}
    - Historial: ${_hitHistory.length} eventos
    ''';
  }
}
