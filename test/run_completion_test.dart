import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/game/run_completion.dart';

Exercise _exercise({int timesCompleted = 0, double bestScore = 0}) {
  return Exercise(
    id: 'initial-1',
    title: 'Exercise 1',
    description: 'Test exercise',
    fileName: '1.musicxml',
    assetPath: 'assets/exercises/inicial/1.musicxml',
    difficulty: Difficulty.initial,
    type: ExerciseType.rhythmTraining,
    timesCompleted: timesCompleted,
    bestScore: bestScore,
  );
}

void main() {
  test('requests results even when the run has no catalog exercise', () {
    var resultsRequested = false;
    var exerciseUpdated = false;

    completeGameRun(
      exercise: null,
      currentScore: 120,
      onExerciseUpdated: (_) => exerciseUpdated = true,
      onShowResults: () => resultsRequested = true,
    );

    expect(resultsRequested, isTrue);
    expect(exerciseUpdated, isFalse);
  });

  test('updates exercise progress and requests results for catalog runs', () {
    Exercise? updatedExercise;
    var resultsRequested = false;

    completeGameRun(
      exercise: _exercise(timesCompleted: 2, bestScore: 100),
      currentScore: 120,
      onExerciseUpdated: (exercise) => updatedExercise = exercise,
      onShowResults: () => resultsRequested = true,
    );

    expect(updatedExercise?.timesCompleted, 3);
    expect(updatedExercise?.bestScore, 120);
    expect(resultsRequested, isTrue);
  });

  test('does not replace a better stored score', () {
    Exercise? updatedExercise;

    completeGameRun(
      exercise: _exercise(timesCompleted: 1, bestScore: 150),
      currentScore: 120,
      onExerciseUpdated: (exercise) => updatedExercise = exercise,
      onShowResults: () {},
    );

    expect(updatedExercise?.timesCompleted, 2);
    expect(updatedExercise?.bestScore, 150);
  });
}
