// lib/screens/game_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/piano_audio_service.dart';
import '../core/core.dart';
import '../core/globals.dart';
import '../game/game.dart';
import '../parsers/musicxml_parser.dart';
import '../providers/exercise_provider.dart';
import '../visual_engine/visual_engine.dart';

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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final AnimationManager _animationManager = AnimationManager();
  final PianoAudioService _pianoAudioService = PianoAudioService();
  static const double _basePixelsPerTick = 0.35;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);
  static const double _staffTop = 60;
  static const double _leftMargin = 80;

  late final AnimationController _repaintController;
  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollFrame;
  bool _isPlaying = false;

  GameSession? _gameSession;
  MusicScore? _loadedScore;
  bool _isLoading = false;
  String _status = 'Cargue un archivo MusicXML para comenzar.';
  double _currentViewportWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _repaintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..repeat();

    _scrollController = ScrollController();
    _initializeAudio();

    if (widget.preloadedContent != null) {
      _loadPreloadedContent(widget.preloadedContent!);
    } else if (widget.preloadedFilePath != null) {
      _loadPreloadedFile(widget.preloadedFilePath!);
    }
  }

  // ===== MÉTODOS DE CARGA =====
  Future<void> _loadPreloadedContent(String content) async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando archivo...';
    });
    try {
      final score = MusicXMLParser.parse(content);
      if (mounted) {
        setState(() {
          _loadedScore = score;
          _isPlaying = false;
          _status = '';
          _gameSession = GameSession(
            ticksEngine: TicksEngine(initialBpm: score.bpm),
            scoreEngine: ScoreEngine(),
            musicScore: score,
          );
          _gameSession!.onNoteHit(() {
            if (mounted) setState(() {});
          });
          _gameSession!.onScoreChange(() {
            if (mounted) setState(() {});
          });
          if (widget.exercise != null) {
            _status = '🎵 ${widget.exercise!.title} - ${widget.exercise!.composer}';
          }
        });
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
        setState(() {
          _loadedScore = score;
          _isPlaying = false;
          _status = '';
          _gameSession = GameSession(
            ticksEngine: TicksEngine(initialBpm: score.bpm),
            scoreEngine: ScoreEngine(),
            musicScore: score,
          );
          _gameSession!.onNoteHit(() {
            if (mounted) setState(() {});
          });
          _gameSession!.onScoreChange(() {
            if (mounted) setState(() {});
          });
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error al cargar archivo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeAudio() async {
    try {
      await _pianoAudioService.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  // ===== MÉTODOS DE CONTROL DEL JUEGO =====
  void _startFromBeginning() {
    if (_gameSession == null) return;
    _gameSession!.restart();
    _gameSession!.start();
    setState(() {
      _isPlaying = true;
      _status = '';
    });
    _startAutoScrollForLoadedScore();
  }

  void _finishGame() {
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  // ===== SCROLL AUTOMÁTICO =====
  void _startAutoScrollForLoadedScore() {
    final score = _loadedScore;
    if (score == null) return;
    _stopAutoScroll();
    _lastAutoScrollFrame = DateTime.now();

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || !_scrollController.hasClients) return;

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
        _stopAutoScroll();
        if (mounted) {
          setState(() => _isPlaying = false);
          _finishGame();
        }
        return;
      }
      _scrollController.jumpTo(nextOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastAutoScrollFrame = null;
  }

  // ===== HANDLE NOTE INPUT =====
  void _handleNoteInput(String pitch) {
    if (_isPlaying && _gameSession != null) {
      _gameSession!.handleNoteInput(pitch);
    }
  }

  // ===== MÉTODOS AUXILIARES PARA RENDERIZADO =====
  double get _pixelsPerTick => _basePixelsPerTick * noteSpacingScale.value;

  double _staticHitLineX(MusicScore score, double viewportWidth) {
    if (score.notes.isEmpty) return _leftMargin + 180.0;
    final baseHitLineX = _leftMargin + 180.0;
    if (viewportWidth <= 0) return baseHitLineX;
    final maxHitLineX = math.max(baseHitLineX, viewportWidth * 0.5);
    final t = musicStartOffsetScale.value.clamp(0.0, 1.0);
    return baseHitLineX + ((maxHitLineX - baseHitLineX) * t);
  }

  // ============================================================
  // MÉTODO BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final game = _gameSession;
    if (_loadedScore == null || game == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Text('Cargue un archivo MusicXML para comenzar.'),
        ),
      );
    }

    final lastHit = game.hitHistory.isNotEmpty ? game.hitHistory.last : null;
    final beatColor = lastHit != null ? Color(lastHit.colorValue) : Colors.grey;

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
                  onPressed: _isPlaying ? null : _startFromBeginning,
                  icon: Icon(
                    _isPlaying ? Icons.play_circle_outline : Icons.play_circle_filled,
                    size: 36,
                    color: _isPlaying ? Colors.grey : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Iniciar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Partitura
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
                      _currentViewportWidth = constraints.maxWidth;
                      final calculatedWidth = (maxTick * _pixelsPerTick) + 160;
                      final width = calculatedWidth < minWidth ? minWidth : calculatedWidth;

                      final staticHitLineX = _staticHitLineX(_loadedScore!, _currentViewportWidth);
                      final perfectWindowHalfWidth = 0.0;

                      return Stack(
                        children: [
                          // Pentagrama con scroll
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
                                child: CustomPaint(
                                  painter: SMuFLRenderer(
                                    timeSignature: _loadedScore!.timeSignature,
                                    keySignature: _loadedScore!.keySignature,
                                    visibleNotes: _loadedScore!.notes,
                                    animationManager: _animationManager,
                                    ticksEngine: TicksEngine(initialBpm: _loadedScore!.bpm),
                                    pixelsPerTick: _pixelsPerTick,
                                    hitLineXOverride: staticHitLineX,
                                    showHitLine: false,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          // Feedback mínimo en la esquina superior derecha
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: beatColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: beatColor.withOpacity(0.5), width: 1),
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
                          ),
                          // Historial de hits
                          Positioned(
                            top: 32,
                            left: 4,
                            child: HitHistoryDisplay(history: game.hitHistory),
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

  @override
  void dispose() {
    _stopAutoScroll();
    _repaintController.dispose();
    _scrollController.dispose();
    _pianoAudioService.dispose();
    _gameSession?.stop();
    super.dispose();
  }
}