import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';

class ExerciseLoaderService {
  static const String _exercisesFolder = 'assets/exercises/';
  static final RegExp _numericMusicXml =
      RegExp(r'^\d+\.(?:musicxml|xml)$', caseSensitive: false);

  final List<Exercise> _exercises = [];
  final Map<String, Exercise> _exerciseMap = {};
  final Map<Difficulty, List<Exercise>> _exercisesByDifficulty = {};
  final Map<ExerciseType, List<Exercise>> _exercisesByType = {};

  Future<List<Exercise>> loadExercises() async {
    try {
      final allAssetPaths = await _loadAllAssetPaths();
      final assetPaths = allAssetPaths
          .where((path) => path.startsWith(_exercisesFolder))
          .where(_isNumericMusicXml)
          .toList()
        ..sort();

      _exercises.clear();
      _exerciseMap.clear();
      _exercisesByDifficulty.clear();
      _exercisesByType.clear();

      for (final assetPath in assetPaths) {
        final exercise = _parseExercise(assetPath);
        _exercises.add(exercise);
        _exerciseMap[exercise.id] = exercise;

        _exercisesByDifficulty.putIfAbsent(exercise.difficulty, () => []);
        _exercisesByDifficulty[exercise.difficulty]!.add(exercise);

        _exercisesByType.putIfAbsent(exercise.type, () => []);
        _exercisesByType[exercise.type]!.add(exercise);
      }

      debugPrint('✅ Cargados ${_exercises.length} ejercicios');
      return _exercises;
    } catch (e) {
      debugPrint('❌ Error cargando ejercicios: $e');
      return [];
    }
  }

  Exercise _parseExercise(String assetPath) {
    final pathParts = assetPath.split('/');
    final level = pathParts[pathParts.length - 2];
    final fileName = pathParts.last;
    final exerciseNumber = fileName.split('.').first;

    return Exercise(
      id: '$level-$exerciseNumber',
      title: 'Ejercicio $exerciseNumber',
      description: 'Ejercicio MusicXML del nivel ${_parseDifficulty(level).displayName}.',
      fileName: fileName,
      assetPath: assetPath,
      difficulty: _parseDifficulty(level),
      type: ExerciseType.rhythmTraining,
      composer: 'Ejercicio Musical',
      bpm: 120,
      estimatedDuration: const Duration(minutes: 2),
      tags: const [],
      isFavorite: false,
      timesCompleted: 0,
      bestScore: 0,
    );
  }

  Difficulty _parseDifficulty(String value) {
    switch (value.toLowerCase()) {
      case 'inicial':
        return Difficulty.initial;
      case 'intermedio':
      case 'intermediate':
        return Difficulty.intermediate;
      case 'avanzado':
      case 'advanced':
        return Difficulty.advanced;
      default:
        throw FormatException('Nivel de ejercicios no soportado: $value');
    }
  }

  /// Lee el listado de assets soportando tanto el manifiesto binario
  /// (AssetManifest.bin, usado por SDKs recientes) como el JSON legado.
  Future<List<String>> _loadAllAssetPaths() async {
    try {
      final data = await rootBundle.load('AssetManifest.bin');
      final decoded = const StandardMessageCodec().decodeMessage(data);
      if (decoded is Map) {
        return decoded.keys.map((key) => key.toString()).toList();
      }
    } catch (_) {
      // Ignorado: se intentará con el manifiesto JSON legado.
    }

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final assetManifest = jsonDecode(manifestJson) as Map<String, dynamic>;
      return assetManifest.keys.toList();
    } catch (_) {
      return [];
    }
  }

  bool _isNumericMusicXml(String path) {
    return _numericMusicXml.hasMatch(path.split('/').last);
  }

  ExerciseType _parseExerciseType(String value) {
    switch (value.toLowerCase()) {
      case 'rhythmtraining':
      case 'rhythm_training':
        return ExerciseType.rhythmTraining;
      case 'pitchrecognition':
      case 'pitch_recognition':
        return ExerciseType.pitchRecognition;
      case 'sightreading':
      case 'sight_reading':
        return ExerciseType.sightReading;
      case 'eartraining':
      case 'ear_training':
        return ExerciseType.earTraining;
      default:
        return ExerciseType.rhythmTraining;
    }
  }

  List<Exercise> get allExercises => List.unmodifiable(_exercises);

  List<Exercise> getExercisesByDifficulty(Difficulty difficulty) {
    return List.unmodifiable(_exercisesByDifficulty[difficulty] ?? []);
  }

  List<Exercise> getExercisesByType(ExerciseType type) {
    return List.unmodifiable(_exercisesByType[type] ?? []);
  }

  Exercise? getExerciseById(String id) {
    return _exerciseMap[id];
  }

  /// Obtiene el primer ejercicio disponible (por defecto es el primero de la lista)
  Exercise? getFirstExercise() {
    return _exercises.isNotEmpty ? _exercises.first : null;
  }

  /// Obtiene los ejercicios por dificultad, ordenados
  Future<Exercise?> loadAndGetFirstExercise() async {
    await loadExercises();
    return getFirstExercise();
  }

  List<Exercise> searchExercises(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises.where((exercise) {
      return exercise.title.toLowerCase().contains(lowerQuery) ||
          exercise.composer.toLowerCase().contains(lowerQuery) ||
          exercise.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  ExerciseStats getStats() {
    final completed = _exercises.where((e) => e.timesCompleted > 0).length;
    final totalScore = _exercises.fold<double>(0, (sum, e) => sum + e.bestScore);
    final avgScore = completed > 0 ? (totalScore / completed) : 0.0; // <-- Forzado a double

    return ExerciseStats(
      totalExercises: _exercises.length,
      completedExercises: completed,
      favoriteCount: _exercises.where((e) => e.isFavorite).length,
      averageBestScore: avgScore,
      totalTimeSpent: Duration(seconds: _exercises.fold<int>(
          0, (sum, e) => sum + (e.timesCompleted * e.estimatedDuration.inSeconds))),
    );
  }
}