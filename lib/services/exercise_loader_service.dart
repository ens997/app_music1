import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';

class ExerciseLoaderService {
  static const String _exercisesFolder = 'assets/exercises';
  static const String _manifestFile = '$_exercisesFolder/exercises_manifest.json';

  final List<Exercise> _exercises = [];
  final Map<String, Exercise> _exerciseMap = {};
  final Map<Difficulty, List<Exercise>> _exercisesByDifficulty = {};
  final Map<ExerciseType, List<Exercise>> _exercisesByType = {};

  Future<List<Exercise>> loadExercises() async {
    try {
      String manifestJson;
      try {
        manifestJson = await rootBundle.loadString(_manifestFile);
      } catch (e) {
        debugPrint('⚠️ Manifiesto no encontrado: $_manifestFile');
        return [];
      }

      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
      final exercisesList = manifest['exercises'] as List<dynamic>;

      _exercises.clear();
      _exerciseMap.clear();
      _exercisesByDifficulty.clear();
      _exercisesByType.clear();

      for (final exerciseData in exercisesList) {
        final exercise = _parseExercise(exerciseData as Map<String, dynamic>);
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

  Exercise _parseExercise(Map<String, dynamic> data) {
    final difficultyStr = data['difficulty'] as String? ?? 'beginner';
    final typeStr = data['type'] as String? ?? 'rhythmTraining';
    final durationSec = data['estimatedDuration'] as int? ?? 120;

    return Exercise(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? 'Sin título',
      description: data['description'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      assetPath: '$_exercisesFolder/${data['path'] as String? ?? ''}',
      difficulty: _parseDifficulty(difficultyStr),
      type: _parseExerciseType(typeStr),
      composer: data['composer'] as String? ?? 'Unknown',
      bpm: data['bpm'] as int? ?? 120,
      estimatedDuration: Duration(seconds: durationSec),
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isFavorite: false,
      timesCompleted: 0,
      bestScore: 0,
    );
  }

  Difficulty _parseDifficulty(String value) {
    switch (value.toLowerCase()) {
      case 'beginner':
        return Difficulty.beginner;
      case 'intermediate':
        return Difficulty.intermediate;
      case 'advanced':
        return Difficulty.advanced;
      case 'expert':
        return Difficulty.expert;
      default:
        return Difficulty.beginner;
    }
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