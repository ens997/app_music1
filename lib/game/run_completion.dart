import '../core/models/exercise_model.dart';

void completeGameRun({
  required Exercise? exercise,
  required int currentScore,
  required void Function(Exercise exercise) onExerciseUpdated,
  required void Function() onShowResults,
}) {
  if (exercise != null) {
    onExerciseUpdated(
      exercise.copyWith(
        timesCompleted: exercise.timesCompleted + 1,
        bestScore: currentScore > exercise.bestScore
            ? currentScore.toDouble()
            : exercise.bestScore,
      ),
    );
  }

  onShowResults();
}
