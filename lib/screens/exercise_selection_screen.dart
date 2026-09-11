// lib/screens/exercise_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/core.dart';
import '../providers/exercise_provider.dart';
import 'game_screen.dart';

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
      length: 3,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _selectedDifficulty = Difficulty.initial;
    _updateFilteredExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _selectedDifficulty = Difficulty.values[_tabController.index];
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
            Tab(text: 'Inicial'),
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
  // Métodos auxiliares
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
      case Difficulty.initial:
        return 'Inicial';
      case Difficulty.intermediate:
        return '⚡ Intermedio';
      case Difficulty.advanced:
        return '🔥 Avanzado';
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