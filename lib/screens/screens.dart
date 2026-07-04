import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/piano_audio_service.dart';
import '../core/core.dart';
import '../parsers/parsers.dart';
import '../services/musicxml_preload_service.dart';
// import '../services/exercise_loader_service.dart'; // ELIMINADO (no se usa)
import '../providers/exercise_provider.dart';
import '../visual_engine/visual_engine.dart';

const double _minNoteSpacingScale = 0.75;
const double _maxNoteSpacingScale = 1.0;
final ValueNotifier<double> _noteSpacingScale = ValueNotifier<double>(_maxNoteSpacingScale);
const double _minMusicStartOffsetScale = 0.0;
const double _maxMusicStartOffsetScale = 1.0;
final ValueNotifier<double> _musicStartOffsetScale = ValueNotifier<double>(_minMusicStartOffsetScale);

enum _HitWindowState { none, early, perfect, late }

class _HitWindowFeedback {
  final _HitWindowState state;
  final double deltaMs;
  final String? notePitch;

  const _HitWindowFeedback({
    required this.state,
    required this.deltaMs,
    this.notePitch,
  });
}

/// Pantalla principal del juego
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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final AnimationManager _animationManager = AnimationManager();
  final PianoAudioService _pianoAudioService = PianoAudioService();
  static const double _basePixelsPerTick = 0.35;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);
  static const double _staffTop = 60;
  static const double _leftMargin = 80;

  double get _pixelsPerTick => _basePixelsPerTick * _noteSpacingScale.value;

  late final AnimationController _repaintController;
  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollFrame;
  bool _isPlaying = false;

  int _currentScore = 0;
  int _currentCombo = 0;
  int _maxCombo = 0;
  Set<int> _hitNoteIndices = {};
  List<_HitWindowState> _hitHistory = [];

  MusicScore? _loadedScore;
  String _status = 'Cargue un archivo MusicXML para comenzar.';
  bool _isLoading = false;
  bool _audioReady = false;
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
          if (widget.exercise != null) {
            _status = '🎵 ${widget.exercise!.title} - ${widget.exercise!.composer}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error al cargar archivo: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error al cargar archivo: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeAudio() async {
    try {
      await _pianoAudioService.initialize();
      if (mounted) {
        setState(() {
          _audioReady = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _repaintController.dispose();
    _scrollController.dispose();
    _pianoAudioService.dispose();
    super.dispose();
  }

  void _startAutoScrollForLoadedScore() {
    final score = _loadedScore;
    if (score == null) return;

    _stopAutoScroll();
    _lastAutoScrollFrame = DateTime.now();

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || !_scrollController.hasClients) return;

      final ticksPerSecond = (TicksEngine.TPQN * score.bpm) / 60.0;
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
          setState(() {
            _isPlaying = false;
          });
          _finishGame();
        }
        return;
      }

      _scrollController.jumpTo(nextOffset);
    });
  }

  void _finishGame() {
    if (widget.exercise != null && mounted) {
      final provider = context.read<ExerciseProvider>();
      final updatedExercise = widget.exercise!.copyWith(
        timesCompleted: widget.exercise!.timesCompleted + 1,
        bestScore: _currentScore > widget.exercise!.bestScore
            ? _currentScore.toDouble()
            : widget.exercise!.bestScore,
      );
      provider.updateExercise(updatedExercise);
      _showResultsDialog();
    }
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
              'Puntuación: $_currentScore',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Combo Máximo: $_maxCombo',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Notas Acertadas: ${_hitNoteIndices.length}',
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

  void _resetAndRestart() {
    setState(() {
      _currentScore = 0;
      _currentCombo = 0;
      _maxCombo = 0;
      _hitNoteIndices.clear();
      _hitHistory.clear();
    });
    _scrollController.jumpTo(0);
    _startFromBeginning();
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastAutoScrollFrame = null;
  }

  void _startFromBeginning() {
    if (_loadedScore == null) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _currentScore = 0;
    _currentCombo = 0;
    _maxCombo = 0;
    _hitNoteIndices.clear();
    _hitHistory.clear();
    setState(() {
      _isPlaying = true;
    });
    _startAutoScrollForLoadedScore();
  }

  void _handleNoteInput(String inputPitch) {
    if (_loadedScore == null || !_isPlaying) return;

    final staticHitLineX = _staticHitLineX(_loadedScore!, _currentViewportWidth);
    final feedback = _computeHitWindowFeedback(_loadedScore!, staticHitLineX);

    if (feedback.state == _HitWindowState.none) return;

    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    NoteModel? hitNote;
    int hitNoteIndex = -1;

    for (int i = 0; i < _loadedScore!.notes.length; i++) {
      final note = _loadedScore!.notes[i];
      if (_hitNoteIndices.contains(i)) continue;

      final noteScoreX = _scoreXForTick(_loadedScore!, note.absoluteTick, staticHitLineX);
      final noteScreenX = noteScoreX - scrollOffset;
      final deltaPx = (noteScreenX - staticHitLineX).abs();

      if (deltaPx < 50.0) {
        hitNote = note;
        hitNoteIndex = i;
        break;
      }
    }

    if (hitNote == null || hitNoteIndex < 0) return;

    _hitNoteIndices.add(hitNoteIndex);

    final expectedPitch = _normalizePitch(hitNote.pitch);
    final playedPitch = _normalizePitch(inputPitch);
    final isCorrectPitch = expectedPitch == playedPitch;

    if (isCorrectPitch && _audioReady) {
      _pianoAudioService.playNote(expectedPitch);
    }

    int points = 0;
    switch (feedback.state) {
      case _HitWindowState.perfect:
        points = isCorrectPitch ? 100 : 20;
        _currentCombo = isCorrectPitch ? _currentCombo + 1 : 0;
        break;
      case _HitWindowState.early:
      case _HitWindowState.late:
        points = isCorrectPitch ? 50 : 10;
        _currentCombo = isCorrectPitch ? _currentCombo + 1 : 0;
        break;
      case _HitWindowState.none:
        _currentCombo = 0;
        break;
    }

    if (_currentCombo > _maxCombo) {
      _maxCombo = _currentCombo;
    }

    _currentScore += points;

    _hitHistory.add(feedback.state);
    if (_hitHistory.length > 12) {
      _hitHistory.removeAt(0);
    }

    _animationManager.addHitFeedback(
      Offset(staticHitLineX, _staffTop + 2 * StaffRenderer.SPACE_HEIGHT),
      !isCorrectPitch
          ? HitQuality.miss
          : feedback.state == _HitWindowState.perfect
              ? HitQuality.perfect
              : feedback.state == _HitWindowState.early || feedback.state == _HitWindowState.late
                  ? HitQuality.good
                  : HitQuality.miss,
    );

    _animationManager.addAccuracyAnimation(
      Offset(staticHitLineX, _staffTop + 2 * StaffRenderer.SPACE_HEIGHT),
      !isCorrectPitch
          ? HitQuality.miss
          : feedback.state == _HitWindowState.perfect
              ? HitQuality.perfect
              : feedback.state == _HitWindowState.early || feedback.state == _HitWindowState.late
                  ? HitQuality.good
                  : HitQuality.miss,
      0,
    );

    if (isCorrectPitch && _currentCombo >= 5) {
      _animationManager.addComboAnimation(
        Offset(staticHitLineX, _staffTop + 2 * StaffRenderer.SPACE_HEIGHT),
        _currentCombo,
      );
    }

    setState(() {});
  }

  String _normalizePitch(String pitch) {
    var p = pitch.trim().toUpperCase();
    if (p.isEmpty) return p;
    p = p.replaceAll('♯', '#').replaceAll('♭', 'B');
    final match = RegExp(r'^([A-G])([#B]?)(\d)$').firstMatch(p);
    if (match == null) return p;

    final note = match.group(1)!;
    final accidental = match.group(2) ?? '';
    final octave = int.parse(match.group(3)!);

    const semitone = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    var value = semitone[note]! + (octave * 12);
    if (accidental == '#') value += 1;
    if (accidental == 'B') value -= 1;

    final normalizedOctave = value ~/ 12;
    final normalizedClass = value % 12;
    const names = {
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

    return '${names[normalizedClass]}$normalizedOctave';
  }

  int _ticksPerMeasure(TimeSignature timeSignature) {
    return (TicksEngine.TPQN * timeSignature.numerator * 4) ~/
        timeSignature.denominator;
  }

  double _scoreXForTick(MusicScore score, int absoluteTick, double hitLineX) {
    final baseTick = score.notes.first.absoluteTick;
    return hitLineX + ((absoluteTick - baseTick) * _pixelsPerTick);
  }

  _HitWindowFeedback _computeHitWindowFeedback(MusicScore score, double hitLineX) {
    if (score.notes.isEmpty) {
      return const _HitWindowFeedback(state: _HitWindowState.none, deltaMs: 0);
    }

    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    NoteModel? closestNote;
    double closestDeltaPx = double.infinity;

    for (final note in score.notes) {
      final noteScoreX = _scoreXForTick(score, note.absoluteTick, hitLineX);
      final noteScreenX = noteScoreX - scrollOffset;
      final deltaPx = noteScreenX - hitLineX;

      if (deltaPx.abs() < closestDeltaPx.abs()) {
        closestDeltaPx = deltaPx;
        closestNote = note;
      }
    }

    if (closestNote == null) {
      return const _HitWindowFeedback(state: _HitWindowState.none, deltaMs: 0);
    }

    final deltaTicks = closestDeltaPx / _pixelsPerTick;
    final deltaMs =
        (deltaTicks / TicksEngine.TPQN) * (60000.0 / score.bpm.toDouble());
    final absMs = deltaMs.abs();

    if (absMs <= 45.0) {
      return _HitWindowFeedback(
        state: _HitWindowState.perfect,
        deltaMs: deltaMs,
        notePitch: closestNote.pitch,
      );
    }

    if (absMs <= 140.0) {
      return _HitWindowFeedback(
        state: deltaMs > 0 ? _HitWindowState.early : _HitWindowState.late,
        deltaMs: deltaMs,
        notePitch: closestNote.pitch,
      );
    }

    return _HitWindowFeedback(
      state: _HitWindowState.none,
      deltaMs: deltaMs,
      notePitch: closestNote.pitch,
    );
  }

  Color _feedbackColor(_HitWindowState state) {
    switch (state) {
      case _HitWindowState.perfect:
        return const Color(0xFF2E7D32);
      case _HitWindowState.early:
      case _HitWindowState.late:
        return const Color(0xFFF9A825);
      case _HitWindowState.none:
        return Colors.red;
    }
  }

  String _feedbackText(_HitWindowFeedback feedback) {
    final note = feedback.notePitch ?? '-';
    final ms = feedback.deltaMs.abs().toStringAsFixed(0);

    switch (feedback.state) {
      case _HitWindowState.perfect:
        return 'Perfecto ($note · ${ms}ms)';
      case _HitWindowState.early:
        return 'Temprano ($note · +${ms}ms)';
      case _HitWindowState.late:
        return 'Tarde ($note · -${ms}ms)';
      case _HitWindowState.none:
        return 'En espera ($note · ${ms}ms)';
    }
  }

  double _perfectWindowHalfWidthPx(MusicScore score) {
    final pixelsPerSecond = (TicksEngine.TPQN * score.bpm / 60.0) * _pixelsPerTick;
    return pixelsPerSecond * 0.045;
  }

  double _staticHitLineX(MusicScore score, double viewportWidth) {
    if (score.notes.isEmpty) return _leftMargin + 180.0;

    final baseHitLineX = _leftMargin + 180.0;

    if (viewportWidth <= 0) return baseHitLineX;

    final maxHitLineX = math.max(baseHitLineX, viewportWidth * 0.5);
    final t = _musicStartOffsetScale.value.clamp(
      _minMusicStartOffsetScale,
      _maxMusicStartOffsetScale,
    );
    return baseHitLineX + ((maxHitLineX - baseHitLineX) * t);
  }

  Future<void> _loadFromAsset() async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando archivo de ejemplo...';
    });

    try {
      final xml = await rootBundle.loadString('assets/sample.musicxml');
      final score = MusicXMLParser.parse(xml);
      setState(() {
        _loadedScore = score;
        _isPlaying = false;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _status = 'Error al parsear archivo de ejemplo: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _status = 'Seleccionando archivo...';
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'musicxml'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = 'No se seleccionó ningún archivo.';
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _status = 'Ruta de archivo no disponible.';
        });
        return;
      }

      final content = await File(path).readAsString();
      final score = MusicXMLParser.parse(content);

      setState(() {
        _loadedScore = score;
        _isPlaying = false;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _status = 'Error al cargar archivo: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    // AppBar completamente vacía (sin título, sin íconos, sin botones)
    appBar: AppBar(
      elevation: 0,
      toolbarHeight: 0, // Ocultamos la AppBar
      automaticallyImplyLeading: false, // Elimina el botón de retroceso automático
    ),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          // Fila de botones: Volver (izquierda) y Play (derecha)
          Row(
            children: [
              // Botón Volver
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 28),
                tooltip: 'Volver',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              // Botón Play
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

          // Partitura (ocupa el espacio restante)
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
                    if (_loadedScore == null) {
                      return const Center(
                        child: Text('Cargue un archivo MusicXML'),
                      );
                    }
                    final maxTick = _loadedScore!.getTotalTicks();
                    final minWidth = constraints.maxWidth;
                    _currentViewportWidth = constraints.maxWidth;
                    final calculatedWidth = (maxTick * _pixelsPerTick) + 160;
                    final width = calculatedWidth < minWidth ? minWidth : calculatedWidth;

                    final staticHitLineX = _staticHitLineX(_loadedScore!, _currentViewportWidth);
                    final feedback = _computeHitWindowFeedback(_loadedScore!, staticHitLineX);
                    final feedbackColor = _feedbackColor(feedback.state);
                    final perfectWindowHalfWidth = _perfectWindowHalfWidthPx(_loadedScore!);

                    return Stack(
                      children: [
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
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _StaticBeatLinePainter(
                              hitLineX: staticHitLineX,
                              staffTop: _staffTop,
                              beatColor: feedbackColor,
                              perfectWindowHalfWidth: perfectWindowHalfWidth,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        // Feedback mínimo en la esquina superior derecha
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: feedbackColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: feedbackColor.withOpacity(0.5), width: 1),
                            ),
                            child: Text(
                              _feedbackText(feedback),
                              style: TextStyle(
                                color: feedbackColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        // Historial de hits (círculos pequeños)
                        Positioned(
                          top: 32,
                          left: 4,
                          right: 4,
                          child: Wrap(
                            spacing: 3,
                            children: _hitHistory.map((state) {
                              Color hitColor;
                              switch (state) {
                                case _HitWindowState.perfect:
                                  hitColor = const Color(0xFF2E7D32);
                                  break;
                                case _HitWindowState.early:
                                case _HitWindowState.late:
                                  hitColor = const Color(0xFFF9A825);
                                  break;
                                case _HitWindowState.none:
                                  hitColor = Colors.red;
                                  break;
                              }
                              return Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: hitColor,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
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
            child: _PianoInput(
              enabled: _isPlaying,
              onNotePressed: _handleNoteInput,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getDifficultyLabel(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Principiante';
      case Difficulty.intermediate:
        return 'Intermedio';
      case Difficulty.advanced:
        return 'Avanzado';
      case Difficulty.expert:
        return 'Experto';
    }
  }
}

class _PianoInput extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onNotePressed;

  const _PianoInput({
    required this.enabled,
    required this.onNotePressed,
  });

  static const List<String> _notes = [
    'C4',
    'C#4',
    'D4',
    'D#4',
    'E4',
    'F4',
    'F#4',
    'G4',
    'G#4',
    'A4',
    'A#4',
    'B4',
    'C5',
    'C#5',
    'D5',
    'D#5',
    'E5',
    'F5',
    'F#5',
    'G5',
    'G#5',
    'A5',
    'A#5',
    'B5',
    'C6',
    'C#6',
    'D6',
    'D#6',
    'E6',
    'F6',
    'F#6',
    'G6',
    'G#6',
    'A6',
    'A#6',
    'B6',
  ];

  bool _isBlack(String n) => n.contains('#');

  @override
  Widget build(BuildContext context) {
    final whiteNotes = _notes.where((n) => !_isBlack(n)).toList();
    final blackNotes = _notes.where(_isBlack).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9DEE8)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Stack(
            children: [
              Row(
                children: whiteNotes.map((note) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: 44,
                      child: ElevatedButton(
                        onPressed: enabled ? () => onNotePressed(note) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFCFD6E3)),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            note,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: Row(
                    children: List.generate(whiteNotes.length, (index) {
                      final note = whiteNotes[index];
                      final nextNote = index + 1 < whiteNotes.length
                          ? whiteNotes[index + 1]
                          : null;
                      final semitoneBetween = _semitone(nextNote) - _semitone(note);
                      final hasBlack = nextNote != null && semitoneBetween == 2;

                      return SizedBox(
                        width: 48,
                        child: Stack(
                          children: [
                            if (hasBlack)
                              Positioned(
                                right: -10,
                                top: 0,
                                child: GestureDetector(
                                  onTap: enabled
                                      ? () {
                                          final black = _sharpBetween(note, nextNote);
                                          if (black != null) onNotePressed(black);
                                        }
                                      : null,
                                  child: Container(
                                    width: 20,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? const Color(0xFF111318)
                                          : const Color(0xFF5A5F6B),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
              if (blackNotes.isNotEmpty)
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  int _semitone(String? pitch) {
    if (pitch == null) return 0;
    final m = RegExp(r'^([A-G])(\d)$').firstMatch(pitch);
    if (m == null) return 0;
    const map = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    return (int.parse(m.group(2)!) * 12) + map[m.group(1)]!;
  }

  String? _sharpBetween(String left, String? right) {
    if (right == null) return null;
    final m = RegExp(r'^([A-G])(\d)$').firstMatch(left);
    if (m == null) return null;
    final note = m.group(1)!;
    final octave = m.group(2)!;
    if (note == 'E' || note == 'B') return null;
    return '$note#$octave';
  }
}

class _StaticBeatLinePainter extends CustomPainter {
  final double hitLineX;
  final double staffTop;
  final Color beatColor;
  final double perfectWindowHalfWidth;

  const _StaticBeatLinePainter({
    required this.hitLineX,
    required this.staffTop,
    required this.beatColor,
    required this.perfectWindowHalfWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final windowRect = Rect.fromLTRB(
      hitLineX - perfectWindowHalfWidth,
      staffTop,
      hitLineX + perfectWindowHalfWidth,
      staffTop + 4 * StaffRenderer.SPACE_HEIGHT,
    );
    canvas.drawRect(
      windowRect,
      Paint()..color = beatColor.withOpacity(0.12),
    );

    canvas.drawLine(
      Offset(hitLineX, staffTop),
      Offset(hitLineX, staffTop + 4 * StaffRenderer.SPACE_HEIGHT),
      Paint()
        ..color = beatColor.withOpacity(0.9)
        ..strokeWidth = 3.0,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'BEAT',
        style: TextStyle(
          color: beatColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(hitLineX - textPainter.width / 2, 40),
    );
  }

  @override
  bool shouldRepaint(covariant _StaticBeatLinePainter oldDelegate) {
    return oldDelegate.hitLineX != hitLineX ||
        oldDelegate.staffTop != staffTop ||
        oldDelegate.beatColor != beatColor ||
        oldDelegate.perfectWindowHalfWidth != perfectWindowHalfWidth;
  }
}

/// Pantalla de configuración
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _spacingScale;
  late double _startOffsetScale;

  @override
  void initState() {
    super.initState();
    _spacingScale = _noteSpacingScale.value;
    _startOffsetScale = _musicStartOffsetScale.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Calibración de Espaciado Horizontal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ajusta la distancia entre notas. 100% (derecha) es el valor actual por defecto y 75% (izquierda) es el mínimo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('75%'),
                  Expanded(
                    child: Slider(
                      min: _minNoteSpacingScale,
                      max: _maxNoteSpacingScale,
                      divisions: 25,
                      value: _spacingScale,
                      label: '${(_spacingScale * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _spacingScale = value;
                        });
                        _noteSpacingScale.value = value;
                      },
                    ),
                  ),
                  const Text('100%'),
                ],
              ),
              Text(
                'Valor actual: ${(_spacingScale * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 18),
              const Text(
                'Calibración del Inicio de la Música',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Mínimo (izquierda): posición actual. Máximo (derecha): mitad de pantalla.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Actual'),
                  Expanded(
                    child: Slider(
                      min: _minMusicStartOffsetScale,
                      max: _maxMusicStartOffsetScale,
                      divisions: 20,
                      value: _startOffsetScale,
                      label: '${(_startOffsetScale * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _startOffsetScale = value;
                        });
                        _musicStartOffsetScale.value = value;
                      },
                    ),
                  ),
                  const Text('Mitad'),
                ],
              ),
              Text(
                'Desplazamiento de inicio: ${(_startOffsetScale * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de selección de niveles (archivos MusicXML precargados)
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final MusicXmlPreloadService _preloadService = MusicXmlPreloadService();
  late Future<List<PreloadedMusicXmlFile>> _filesFuture;
  PreloadedMusicXmlFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadAvailableLevels();
  }

  Future<List<PreloadedMusicXmlFile>> _loadAvailableLevels() async {
    try {
      final discoveredFiles = await _preloadService.discover();
      if (discoveredFiles.isNotEmpty) {
        return discoveredFiles;
      }

      return await _loadLevelsFromAssets();
    } catch (e) {
      return await _loadLevelsFromAssets();
    }
  }

  Future<List<PreloadedMusicXmlFile>> _loadLevelsFromAssets() async {
    try {
      final manifestJson =
          await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      final musicxmlFiles = manifest.keys
          .where((String key) =>
              key.startsWith('musicxml_preload/') &&
              (key.endsWith('.xml') || key.endsWith('.musicxml')))
          .toList();

      musicxmlFiles.sort();

      return musicxmlFiles
          .map((path) {
            final fileName = path.split('/').last;
            return PreloadedMusicXmlFile(
              name: fileName,
              path: path,
            );
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Nivel'),
      ),
      body: FutureBuilder<List<PreloadedMusicXmlFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando archivos MusicXML...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron archivos MusicXML\n\nColoca archivos .xml o .musicxml\nen la carpeta musicxml_preload/',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filesFuture = _loadAvailableLevels();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        selected: _selectedFile == file,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.14),
                        leading: const Icon(Icons.music_note),
                        title: Text(file.name),
                        trailing: _selectedFile == file
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedFile = file;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectedFile == null
                          ? 'Seleccione un nivel para activar el botón Iniciar.'
                          : 'Nivel seleccionado: ${_selectedFile!.name}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                      onPressed: _selectedFile == null
                          ? null
                          : () async {
                              try {
                                final file = _selectedFile!;
                                if (file.path.startsWith('musicxml_preload/')) {
                                  final content =
                                      await rootBundle.loadString(file.path);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        preloadedContent: content,
                                        fileName: file.name,
                                      ),
                                    ),
                                  );
                                } else {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        preloadedFilePath: file.path,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error al iniciar nivel: $e'),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pantalla de resultados
class ResultsScreen extends StatelessWidget {
  final String summary;
  final Exercise? exercise;

  const ResultsScreen({
    Key? key,
    required this.summary,
    this.exercise,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '📊 Resultados',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (exercise != null) ...[
              Text('Ejercicio: ${exercise!.title}'),
              Text('Compositor: ${exercise!.composer}'),
              const Divider(),
            ],
            Text(summary),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Volver al Menú'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Pantalla de selección de ejercicios (añadir al final de screens.dart)
// ============================================================

/// Pantalla para seleccionar ejercicios precargados
class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseSelectionScreen> createState() =>
      _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  Difficulty? _selectedDifficulty;
  ExerciseType? _selectedType;
  List<Exercise> _filteredExercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _updateFilteredExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _selectedDifficulty = null;
      _selectedType = null;
      _searchQuery = '';
      _updateFilteredExercises();
    });
  }

  void _updateFilteredExercises() {
    final provider = context.read<ExerciseProvider>();
    var exercises = provider.exercises;

    if (_searchQuery.isNotEmpty) {
      exercises = provider.searchExercises(_searchQuery);
    }

    if (_selectedDifficulty != null) {
      exercises = exercises
          .where((e) => e.difficulty == _selectedDifficulty)
          .toList();
    }

    if (_selectedType != null) {
      exercises = exercises.where((e) => e.type == _selectedType).toList();
    }

    setState(() {
      _filteredExercises = exercises;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Elegir Ejercicio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '📚 Todos'),
            Tab(text: '🌱 Principiante'),
            Tab(text: '⚡ Intermedio'),
            Tab(text: '🔥 Avanzado'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando ejercicios...'),
                ],
              ),
            )
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(provider.error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.loadExercises(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _filteredExercises.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No se encontraron ejercicios'
                                : 'No hay ejercicios disponibles',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Intenta con otra búsqueda'
                                : 'Carga algunos ejercicios en la carpeta assets/exercises',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : _buildExerciseList(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showStatsDialog(context, provider.getStats());
        },
        icon: const Icon(Icons.insights),
        label: const Text('Estadísticas'),
      ),
    );
  }

  // ------------------------------------------------------------
  // Métodos auxiliares (copia los que ya tenías)
  // ------------------------------------------------------------
  Widget _buildExerciseList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredExercises.length,
      itemBuilder: (context, index) {
        final exercise = _filteredExercises[index];
        return _buildExerciseCard(context, exercise);
      },
    );
  }

  Widget _buildExerciseCard(BuildContext context, Exercise exercise) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<ExerciseProvider>().selectExercise(exercise);
          _loadExerciseAndNavigate(context, exercise);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: exercise.difficultyColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  exercise.icon,
                  color: exercise.difficultyColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (exercise.isFavorite)
                          const Icon(Icons.favorite,
                              color: Colors.red, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChip(
                          context,
                          _getDifficultyLabel(exercise.difficulty),
                          exercise.difficultyColor,
                        ),
                        _buildChip(
                          context,
                          _getTypeLabel(exercise.type),
                          colorScheme.primary,
                        ),
                        _buildChip(
                          context,
                          '${exercise.bpm} BPM',
                          Colors.blue,
                        ),
                        _buildChip(
                          context,
                          exercise.estimatedDurationString,
                          Colors.orange,
                        ),
                        if (exercise.timesCompleted > 0)
                          _buildChip(
                            context,
                            '✅ ${exercise.timesCompleted}x',
                            Colors.green,
                          ),
                        if (exercise.bestScore > 0)
                          _buildChip(
                            context,
                            '🏆 ${exercise.bestScore.toStringAsFixed(0)}',
                            Colors.amber,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getDifficultyLabel(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return '🌱 Principiante';
      case Difficulty.intermediate:
        return '⚡ Intermedio';
      case Difficulty.advanced:
        return '🔥 Avanzado';
      case Difficulty.expert:
        return '💪 Experto';
    }
  }

  String _getTypeLabel(ExerciseType type) {
    switch (type) {
      case ExerciseType.rhythmTraining:
        return '🎵 Ritmo';
      case ExerciseType.pitchRecognition:
        return '🎯 Alturas';
      case ExerciseType.sightReading:
        return '👁️ Lectura';
      case ExerciseType.earTraining:
        return '👂 Oído';
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 Buscar Ejercicios'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Título, compositor o tags',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _updateFilteredExercises();
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _updateFilteredExercises();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 Filtrar Ejercicios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dificultad:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Difficulty.values.map((difficulty) {
                return FilterChip(
                  label: Text(_getDifficultyLabel(difficulty)),
                  selected: _selectedDifficulty == difficulty,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDifficulty = selected ? difficulty : null;
                      _updateFilteredExercises();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ExerciseType.values.map((type) {
                return FilterChip(
                  label: Text(_getTypeLabel(type)),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : null;
                      _updateFilteredExercises();
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDifficulty = null;
                _selectedType = null;
                _updateFilteredExercises();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar filtros'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context, ExerciseStats stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Estadísticas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total ejercicios', '${stats.totalExercises}'),
            _buildStatRow('Completados', '${stats.completedExercises}'),
            _buildStatRow('Favoritos', '${stats.favoriteCount}'),
            _buildStatRow('Tasa de progreso',
                '${stats.completionRate.toStringAsFixed(1)}%'),
            _buildStatRow('Puntuación promedio',
                '${stats.averageBestScore.toStringAsFixed(0)} pts'),
            _buildStatRow('Tiempo total',
                _formatDuration(stats.totalTimeSpent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _loadExerciseAndNavigate(BuildContext context, Exercise exercise) async {
    try {
      final content = await rootBundle.loadString(exercise.assetPath);
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            preloadedContent: content,
            fileName: exercise.fileName,
            exercise: exercise,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error cargando ejercicio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}