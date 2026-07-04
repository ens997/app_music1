import 'package:flutter/material.dart';
import '../services/exercise_loader_service.dart';
import '../core/core.dart'; // <-- Importa core.dart

class ExerciseProvider extends ChangeNotifier {
  final ExerciseLoaderService _loader = ExerciseLoaderService();
  List<Exercise> _exercises = [];
  bool _isLoading = false;
  String? _error;
  Exercise? _selectedExercise;

  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Exercise? get selectedExercise => _selectedExercise;

  Future<void> loadExercises() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _exercises = await _loader.loadExercises();
    } catch (e) {
      _error = 'Error cargando ejercicios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectExercise(Exercise exercise) {
    _selectedExercise = exercise;
    notifyListeners();
  }

  void clearSelection() {
    _selectedExercise = null;
    notifyListeners();
  }

  void updateExercise(Exercise updatedExercise) {
    final index = _exercises.indexWhere((e) => e.id == updatedExercise.id);
    if (index != -1) {
      _exercises[index] = updatedExercise;
      notifyListeners();
    }
  }

  ExerciseStats getStats() {
    return _loader.getStats();
  }

  List<Exercise> searchExercises(String query) {
    return _loader.searchExercises(query);
  }
}