import 'package:flutter/material.dart'; // <-- ESTE IMPORT ES CRÍTICO
import 'enumerations.dart';

/// Modelo que representa un ejercicio musical precargado
class Exercise {
  final String id;
  final String title;
  final String description;
  final String fileName;
  final String assetPath;
  final Difficulty difficulty;
  final ExerciseType type;
  final String composer;
  final int bpm;
  final Duration estimatedDuration;
  final List<String> tags;
  final bool isFavorite;
  final int timesCompleted;
  final double bestScore;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.assetPath,
    required this.difficulty,
    required this.type,
    this.composer = 'Unknown',
    this.bpm = 120,
    this.estimatedDuration = const Duration(minutes: 2),
    this.tags = const [],
    this.isFavorite = false,
    this.timesCompleted = 0,
    this.bestScore = 0,
  });

  Exercise copyWith({
    String? id,
    String? title,
    String? description,
    String? fileName,
    String? assetPath,
    Difficulty? difficulty,
    ExerciseType? type,
    String? composer,
    int? bpm,
    Duration? estimatedDuration,
    List<String>? tags,
    bool? isFavorite,
    int? timesCompleted,
    double? bestScore,
  }) {
    return Exercise(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      assetPath: assetPath ?? this.assetPath,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      composer: composer ?? this.composer,
      bpm: bpm ?? this.bpm,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      timesCompleted: timesCompleted ?? this.timesCompleted,
      bestScore: bestScore ?? this.bestScore,
    );
  }

  IconData get icon {
    switch (type) {
      case ExerciseType.rhythmTraining:
        return Icons.music_note;
      case ExerciseType.pitchRecognition:
        return Icons.tune;
      case ExerciseType.sightReading:
        return Icons.visibility;
      case ExerciseType.earTraining:
        return Icons.hearing;
    }
  }

  Color get difficultyColor {
    switch (difficulty) {
      case Difficulty.initial:
        return Colors.green;
      case Difficulty.intermediate:
        return Colors.orange;
      case Difficulty.advanced:
        return Colors.red;
    }
  }

  String get estimatedDurationString {
    if (estimatedDuration.inSeconds < 60) {
      return '${estimatedDuration.inSeconds}s';
    }
    return '${estimatedDuration.inMinutes}m ${estimatedDuration.inSeconds % 60}s';
  }

  @override
  String toString() => 'Exercise($title, $difficulty, $type)';
}

/// Estadísticas de ejercicios
class ExerciseStats {
  final int totalExercises;
  final int completedExercises;
  final int favoriteCount;
  final double averageBestScore;
  final Duration totalTimeSpent;

  ExerciseStats({
    required this.totalExercises,
    required this.completedExercises,
    required this.favoriteCount,
    required this.averageBestScore,
    required this.totalTimeSpent,
  });

  double get completionRate =>
      totalExercises > 0 ? completedExercises / totalExercises * 100 : 0;
}