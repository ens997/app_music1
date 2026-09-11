import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/game_audio_track_controller.dart';
import '../audio/piano_audio_service.dart';
import '../core/core.dart';
import '../core/globals.dart';
import '../game/game.dart';
import '../parsers/musicxml_parser.dart';
import '../providers/exercise_provider.dart';
import '../services/exercise_loader_service.dart';
import '../visual_engine/visual_engine.dart';
import '../visual_engine/note_layout.dart';

class GameScreen extends StatefulWidget {
  final String? preloadedFilePath;
  final String? preloadedContent;
  final String? fileName;
  final Exercise? exercise;

  const GameScreen({
    Key? key,
    this.preloadedFilePath,
    this.preloadedContent,
    this.fileName,
    this.exercise,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AnimationManager _animationManager = AnimationManager();
  final GameAudioTrackController _gameAudioTrackController =
      GameAudioTrackController();
  final PianoAudioService _pianoAudioService = PianoAudioService();
  static const double _basePixelsPerTick = 0.35;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);
  static const double _staffTop = SMuFLRenderer.compactStaffTop;
  static const double _leftMargin = 80;

  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollFrame;
  bool _isPlaying = false;
  bool _isPreparing = false;
  late final Future<void> _audioInitialization;

  GameSession? _gameSession;
  MusicScore? _loadedScore;
  bool _isLoading = false;
  String _status = '';
  double _currentViewportWidth = 0.0;

  // --- ValueNotifier para los layouts precalculados ---
  final ValueNotifier<List<NoteLayout>> _noteLayoutsNotifier =
      ValueNotifier<List<NoteLayout>>([]);

  // --- ValueNotifier para el offset del scroll ---
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  final ValueNotifier<int> _gameRevision = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });

    noteSpacingScale.addListener(_updateNoteLayouts);
    musicStartOffsetScale.addListener(_updateNoteLayouts);

    _audioInitialization = _initializeAudio();
    _audioInitialization.then((_) => _loadConfiguredContent()).catchError((e) {
      debugPrint('Error inicializando audio: $e');
      _loadConfiguredContent();
    });
  }

  Future<void> _loadConfiguredContent() async {
    if (!mounted) return;

    if (widget.preloadedContent != null) {
      await _loadPreloadedContent(widget.preloadedContent!);
      return;
    }

    if (widget.preloadedFilePath != null) {
      await _loadPreloadedFile(widget.preloadedFilePath!);
      return;
    }

    await _loadFirstExerciseAutomatically();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    unawaited(_gameAudioTrackController.dispose());
    _pianoAudioService.dispose();
    _gameSession?.stop();
    _noteLayoutsNotifier.dispose();
    _scrollOffset.dispose();
    _gameRevision.dispose();
    noteSpacingScale.removeListener(_updateNoteLayouts);
    musicStartOffsetScale.removeListener(_updateNoteLayouts);
    super.dispose();
  }

  // ============================================================
  // MÉTODOS DE CARGA
  // ============================================================

  Future<void> _loadPreloadedContent(String content) async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando archivo...';
    });
    try {
      final score = MusicXMLParser.parse(content);
      if (mounted) {
        if (widget.exercise != null) {
          await _gameAudioTrackController.prepare(widget.exercise!.assetPath);
        } else if (widget.fileName != null) {
          await _gameAudioTrackController.prepareFromAssetName(
            widget.fileName!,
          );
        }
        if (!mounted) return;
        setState(() {
          _loadedScore = score;
          _isPlaying = false;
          _status = '';
          _gameSession = GameSession(
            ticksEngine: TicksEngine(initialBpm: score.bpm),
            scoreEngine: ScoreEngine(),
            musicScore: score,
            audioService: _pianoAudioService,
          );
          _attachGameSessionListeners();
          if (widget.exercise != null) {
            _status =
                '🎵 ${widget.exercise!.title} - ${widget.exercise!.composer}';
          }
        });
        _updateNoteLayouts();
        await _prepareForPlayback();
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error al cargar archivo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPreloadedFile(String filePath) async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando archivo...';
    });
    try {
      final content = await File(filePath).readAsString();
      final score = MusicXMLParser.parse(content);
      if (mounted) {
        await _gameAudioTrackController.prepare(filePath);
        if (!mounted) return;
        setState(() {
          _loadedScore = score;
          _isPlaying = false;
          _status = '';
          _gameSession = GameSession(
            ticksEngine: TicksEngine(initialBpm: score.bpm),
            scoreEngine: ScoreEngine(),
            musicScore: score,
            audioService: _pianoAudioService,
          );
          _attachGameSessionListeners();
        });
        _updateNoteLayouts();
        await _prepareForPlayback();
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error al cargar archivo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carga automáticamente el primer ejercicio disponible desde assets
  Future<void> _loadFirstExerciseAutomatically() async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando ejercicio inicial...';
    });

    try {
      final loader = ExerciseLoaderService();
      final exercises = await loader.loadExercises();

      if (exercises.isEmpty) {
        if (mounted) {
          setState(() => _status = 'No hay ejercicios disponibles');
        }
        return;
      }

      final firstExercise = exercises.first;
      final content = await rootBundle.loadString(firstExercise.assetPath);

      if (!mounted) return;

      final score = MusicXMLParser.parse(content);
      await _gameAudioTrackController.prepare(firstExercise.assetPath);
      if (!mounted) return;
      setState(() {
        _loadedScore = score;
        _isPlaying = false;
        _status = '🎵 ${firstExercise.title} - ${firstExercise.composer}';
        _gameSession = GameSession(
          ticksEngine: TicksEngine(initialBpm: score.bpm),
          scoreEngine: ScoreEngine(),
          musicScore: score,
          audioService: _pianoAudioService,
        );
        _attachGameSessionListeners();
      });
      _updateNoteLayouts();
      await _prepareForPlayback();
    } catch (e) {
      if (mounted) {
        setState(() => _status = '❌ Error cargando ejercicio: $e');
        debugPrint('Error loading first exercise: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Registra los listeners de GameSession comunes a todas las rutas de carga:
  /// revisión de UI en cada hit y feedback visual minimalista por nota.
  void _attachGameSessionListeners() {
    final session = _gameSession!;
    session.onNoteHit(() {
      if (mounted) _gameRevision.value++;
    });
    session.onNoteFeedback((noteIndex, quality, isCorrectPitch) {
      final layouts = _noteLayoutsNotifier.value;
      if (noteIndex < 0 || noteIndex >= layouts.length) return;
      final tier = FeedbackTier.fromHit(quality, isCorrectPitch);
      _animationManager.addHitFeedback(layouts[noteIndex].position, tier);
    });
  }

  Future<void> _initializeAudio() async {
    try {
      await _pianoAudioService.initialize();
    } catch (_) {
      // El juego puede continuar aunque el dispositivo no tenga audio.
    }
  }

  Future<void> _prepareForPlayback() async {
    if (!mounted) return;
    setState(() => _isPreparing = true);

    await _audioInitialization;
    if (!mounted) return;

    // Esperar a que el primer layout y la cache visual se hayan pintado.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _isPreparing = false);
  }

  // ============================================================
  // PRECÁLCULO DE LAYOUTS DE NOTAS (FUNCIÓN CORREGIDA)
  // ============================================================

  void _updateNoteLayouts() {
    final score = _loadedScore;
    if (score == null) return;
    if (score.notes.isEmpty) {
      _noteLayoutsNotifier.value = [];
      return;
    }

    final hitLineX = _computeHitLineX();
    final pixelsPerTick = _pixelsPerTick;
    final baseTick = score.notes.first.absoluteTick;

    final layouts = score.notes.map((note) {
      final x = hitLineX + ((note.absoluteTick - baseTick) * pixelsPerTick);
      final staffPosition =
          NoteVisual.notePositions[NoteVisual.basePitchKey(note.pitch)] ?? 5;
      final y = StaffRenderer.getNoteYPosition(_staffTop, staffPosition);
      return NoteLayout(note, Offset(x, y));
    }).toList();

    _noteLayoutsNotifier.value = layouts;
  }

  double _computeHitLineX() {
    // La línea de detección debe permanecer fija en la posición inicial del flujo.
    // El scroll debe afectar únicamente la partitura, no la zona de acierto.
    return _leftMargin + 180.0;
  }

  double get _pixelsPerTick => _basePixelsPerTick * noteSpacingScale.value;

  // ============================================================
  // MÉTODOS DE CONTROL DEL JUEGO
  // ============================================================

  void _startFromBeginning() {
    if (_gameSession == null || _isPreparing) return;
    _gameSession!.restart();
    _gameSession!.start();
    setState(() {
      _isPlaying = true;
      _status = '';
    });
    unawaited(_gameAudioTrackController.playFromStart());
    _startAutoScrollForLoadedScore();
  }

  void _finishGame() {
    unawaited(_gameAudioTrackController.stop());
    _gameSession?.finish();
    if (widget.exercise != null && mounted) {
      final provider = context.read<ExerciseProvider>();
      final updatedExercise = widget.exercise!.copyWith(
        timesCompleted: widget.exercise!.timesCompleted + 1,
        bestScore: _gameSession!.currentScore > widget.exercise!.bestScore
            ? _gameSession!.currentScore.toDouble()
            : widget.exercise!.bestScore,
      );
      provider.updateExercise(updatedExercise);
      _showResultsDialog();
    }
  }

  void _resetAndRestart() {
    unawaited(_gameAudioTrackController.stop());
    _gameSession?.restart();
    _scrollController.jumpTo(0);
    setState(() {});
    _startFromBeginning();
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 ¡Ejercicio Completado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Puntuación: ${_gameSession?.currentScore ?? 0}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Combo Máximo: ${_gameSession?.maxCombo ?? 0}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Notas Acertadas: ${_gameSession?.hitNoteIndices.length ?? 0}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (widget.exercise != null) ...[
              const Divider(),
              Text(
                '🏆 Mejor Puntuación: ${widget.exercise!.bestScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '✅ Veces completado: ${widget.exercise!.timesCompleted}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Volver a Ejercicios'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAndRestart();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCROLL AUTOMÁTICO
  // ============================================================

  void _startAutoScrollForLoadedScore() {
    final score = _loadedScore;
    if (score == null) return;
    _stopAutoScroll();
    _lastAutoScrollFrame = DateTime.now();

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) async {
      if (!mounted || !_scrollController.hasClients || _gameSession == null)
        return;

      // Actualizar la sesión del juego (incluye ticksEngine y metrónomo)
      await _gameSession!.update();

      if (!_gameSession!.hasPlayableNotes ||
          _gameSession!.ticksEngine.currentTick >=
              _gameSession!.completionTick) {
        _stopAutoScroll();
        if (mounted) {
          setState(() => _isPlaying = false);
          _finishGame();
        }
        return;
      }

      final ticksPerSecond = (TicksEngine.tpnq * score.bpm) / 60.0;
      final pixelsPerSecond = ticksPerSecond * _pixelsPerTick;

      final now = DateTime.now();
      final last = _lastAutoScrollFrame ?? now;
      _lastAutoScrollFrame = now;

      final dtSeconds = now.difference(last).inMicroseconds / 1000000.0;
      if (dtSeconds <= 0) return;

      final currentOffset = _scrollController.offset;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final nextOffset = currentOffset + (pixelsPerSecond * dtSeconds);

      if (nextOffset >= maxOffset) {
        _scrollController.jumpTo(maxOffset);
      } else {
        _scrollController.jumpTo(nextOffset);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastAutoScrollFrame = null;
  }

  // ============================================================
  // HANDLE NOTE INPUT
  // ============================================================

  Future<void> _handleNoteInput(String pitch) async {
    if (!_isPlaying || _gameSession == null) return;

    final hitSucceeded = _gameSession!.handleNoteInput(pitch);
    if (!hitSucceeded) return;

    try {
      await _pianoAudioService.initialize();
      await _pianoAudioService.playNote(pitch);
    } catch (_) {
      // Ignorar errores de audio para no bloquear la experiencia de juego.
    }
  }

  // ============================================================
  // MÉTODO BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final game = _gameSession;
    if (_loadedScore == null || game == null) {
      final loadingMessage = _status.isNotEmpty
          ? _status
          : 'Cargando ejercicio...';
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(loadingMessage, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      );
    }

    // Actualizar layouts si es necesario (cuando cambian escalas) - ya se hace via listeners
    // No llamar a _updateNoteLayouts aquí para evitar cálculos en cada build

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            // Fila de botones
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 28),
                  tooltip: 'Volver',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isPlaying || _isPreparing
                      ? null
                      : _startFromBeginning,
                  icon: Icon(
                    _isPlaying
                        ? Icons.play_circle_outline
                        : Icons.play_circle_filled,
                    size: 36,
                    color: _isPlaying
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Iniciar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Controles del metrónomo
            if (_gameSession != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    // Icono del metrónomo
                    Icon(
                      Icons.music_note,
                      size: 20,
                      color: _gameSession!.metronomeController.isEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),

                    // Toggle del metrónomo
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_gameSession!.metronomeController.isEnabled) {
                            _gameSession!.metronomeController.stop();
                          } else {
                            _gameSession!.metronomeController.start();
                          }
                        });
                      },
                      child: Text(
                        _gameSession!.metronomeController.isEnabled
                            ? 'Metrónomo ON'
                            : 'Metrónomo OFF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _gameSession!.metronomeController.isEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Beat actual
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Beat: ${_gameSession!.metronomeController.currentBeat}/${_gameSession!.musicScore.timeSignature.numerator}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value:
                                  _gameSession!
                                      .metronomeController
                                      .currentBeat /
                                  _gameSession!
                                      .musicScore
                                      .timeSignature
                                      .numerator,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Slider de volumen
                    SizedBox(
                      width: 80,
                      child: Slider(
                        value: _gameSession!.metronomeController.volume,
                        onChanged: (newVolume) {
                          setState(() {
                            _gameSession!.metronomeController.setVolume(
                              newVolume,
                            );
                          });
                        },
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label:
                            '${(_gameSession!.metronomeController.volume * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),

            // Partitura optimizada con ValueListenableBuilder y AnimatedBuilder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxTick = _loadedScore!.getTotalTicks();
                      final minWidth = constraints.maxWidth;
                      final newViewportWidth = constraints.maxWidth;
                      if (newViewportWidth != _currentViewportWidth) {
                        _currentViewportWidth = newViewportWidth;
                        _updateNoteLayouts(); // recalcular si cambia el ancho
                      }
                      final calculatedWidth = (maxTick * _pixelsPerTick) + 160;
                      final width = calculatedWidth < minWidth
                          ? minWidth
                          : calculatedWidth;

                      return Stack(
                        children: [
                          // Pentagrama con scroll y AnimatedBuilder
                          Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            thickness: 8,
                            radius: const Radius.circular(6),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: width,
                                child: RepaintBoundary(
                                  child:
                                      ValueListenableBuilder<List<NoteLayout>>(
                                        valueListenable: _noteLayoutsNotifier,
                                        builder: (context, noteLayouts, child) {
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CustomPaint(
                                                painter: SMuFLRenderer(
                                                  timeSignature: _loadedScore!
                                                      .timeSignature,
                                                  keySignature: _loadedScore!
                                                      .keySignature,
                                                  noteLayouts: noteLayouts,
                                                  animationManager:
                                                      _animationManager,
                                                  hitLineXOverride:
                                                      _computeHitLineX(),
                                                  showHitLine: false,
                                                  showStaff: true,
                                                  showNotes: false,
                                                  showBeams: true,
                                                  clefType: ClefType.treble,
                                                  showTimeSignature: true,
                                                  showKeySignature: true,
                                                  showBarLines: true,
                                                  viewportWidth:
                                                      _currentViewportWidth,
                                                ),
                                              ),
                                              CustomPaint(
                                                painter: SMuFLRenderer(
                                                  timeSignature: _loadedScore!
                                                      .timeSignature,
                                                  keySignature: _loadedScore!
                                                      .keySignature,
                                                  noteLayouts: noteLayouts,
                                                  animationManager:
                                                      _animationManager,
                                                  hitLineXOverride:
                                                      _computeHitLineX(),
                                                  showHitLine: false,
                                                  showStaff: false,
                                                  showNotes: true,
                                                  showBeams: false,
                                                  clefType: ClefType.treble,
                                                  showTimeSignature: false,
                                                  showKeySignature: false,
                                                  showBarLines: false,
                                                  scrollOffset:
                                                      _scrollOffset.value,
                                                  scrollOffsetListenable:
                                                      _scrollOffset,
                                                  repaint: Listenable.merge([
                                                    _scrollOffset,
                                                    _gameRevision,
                                                  ]),
                                                  viewportWidth:
                                                      _currentViewportWidth,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                ),
                              ),
                            ),
                          ),
                          // Línea de detección fija, fuera del scroll horizontal.
                          ValueListenableBuilder<int>(
                            valueListenable: _gameRevision,
                            builder: (context, revision, child) {
                              final lastHit = game.hitHistory.isNotEmpty
                                  ? game.hitHistory.last
                                  : null;
                              final beatColor = lastHit != null
                                  ? Color(lastHit.colorValue)
                                  : Colors.grey;
                              return Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: BeatLine(
                                    hitLineX: _computeHitLineX(),
                                    staffTop: SMuFLRenderer.compactStaffTop,
                                    beatColor: beatColor,
                                    perfectWindowHalfWidth: 18,
                                    label: 'BEAT',
                                    lineWidth: 3,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Feedback mínimo en la esquina superior derecha
                          ValueListenableBuilder<int>(
                            valueListenable: _gameRevision,
                            builder: (context, revision, child) {
                              final lastHit = game.hitHistory.isNotEmpty
                                  ? game.hitHistory.last
                                  : null;
                              final beatColor = lastHit != null
                                  ? Color(lastHit.colorValue)
                                  : Colors.grey;
                              return Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: beatColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: beatColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    lastHit?.displayName ?? 'Esperando...',
                                    style: TextStyle(
                                      color: beatColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Historial de hits
                          ValueListenableBuilder<int>(
                            valueListenable: _gameRevision,
                            builder: (context, revision, child) {
                              return Positioned(
                                top: 32,
                                left: 4,
                                child: HitHistoryDisplay(
                                  history: game.hitHistory,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Piano
            SizedBox(
              height: 120,
              child: PianoInput(
                enabled: _isPlaying,
                onNotePressed: _handleNoteInput,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
