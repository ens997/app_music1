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
import '../providers/exercise_provider.dart';
import '../visual_engine/visual_engine.dart';
import '../game/game.dart';

const double _minNoteSpacingScale = 0.75;
const double _maxNoteSpacingScale = 1.0;
final ValueNotifier<double> _noteSpacingScale = ValueNotifier<double>(_maxNoteSpacingScale);
const double _minMusicStartOffsetScale = 0.0;
const double _maxMusicStartOffsetScale = 1.0;
final ValueNotifier<double> _musicStartOffsetScale = ValueNotifier<double>(_minMusicStartOffsetScale);

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
          // Crear la sesión de juego
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

  // ===== HANDLE NOTE INPUT (DELEGADO) =====
  void _handleNoteInput(String pitch) {
    if (_isPlaying && _gameSession != null) {
      _gameSession!.handleNoteInput(pitch);
    }
  }

  // ===== MÉTODOS AUXILIARES PARA RENDERIZADO =====
  double get _pixelsPerTick => _basePixelsPerTick * _noteSpacingScale.value;

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

  

  // ============================================================
  // MÉTODO BUILD (COMPLETO Y REFACTORIZADO)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final game = _gameSession;
    // Si no hay sesión o no hay partitura cargada, mostrar carga o mensaje
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
            // Fila de botones: Volver (izquierda) y Play (derecha)
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
                          // Línea de beat con color dinámico
                          IgnorePointer(
                            
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
                          // Historial de hits (círculos pequeños)
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

  // ============================================================
  // DISPOSE Y OTROS MÉTODOS DE CICLO DE VIDA
  // ============================================================
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