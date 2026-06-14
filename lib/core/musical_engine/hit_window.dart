import 'dart:math';
import '../models/models.dart';
import 'ticks_engine.dart';

/// Define las ventanas de hit (tolerancia) para diferentes calidades de precisión
class HitWindow {
  final TicksEngine engine;

  // Ventanas en ticks
  late int perfectWindow;
  late int greatWindow;
  late int goodWindow;

  HitWindow(this.engine) {
    _updateWindows();
  }

  /// Actualiza las ventanas basadas en el BPM actual
  void _updateWindows() {
    // Las ventanas son constantes en tiempo real (milisegundos)
    const perfectMs = 50;   // ±50ms
    const greatMs = 100;    // ±100ms
    const goodMs = 150;     // ±150ms

    // Convertir a ticks basados en BPM actual
    perfectWindow = engine.millisecondsToTicks(perfectMs.toDouble());
    greatWindow = engine.millisecondsToTicks(greatMs.toDouble());
    goodWindow = engine.millisecondsToTicks(goodMs.toDouble());
  }

  /// Retorna la calidad del hit basada en la desviación en ticks
  HitQuality getQuality(int deviationTicks) {
    final absDev = deviationTicks.abs();

    if (absDev <= perfectWindow) return HitQuality.perfect;
    if (absDev <= greatWindow) return HitQuality.great;
    if (absDev <= goodWindow) return HitQuality.good;
    return HitQuality.miss;
  }

  /// Retorna los puntos para una calidad específica
  int getScore(HitQuality quality) {
    return quality.getScore();
  }

  /// Información de las ventanas en milisegundos
  List<int> getWindowsInMilliseconds() {
    return [
      engine.ticksToMilliseconds(perfectWindow).toInt(),
      engine.ticksToMilliseconds(greatWindow).toInt(),
      engine.ticksToMilliseconds(goodWindow).toInt(),
    ];
  }

  @override
  String toString() {
    final windowsMs = getWindowsInMilliseconds();
    return 'HitWindow(perfect: ±${windowsMs[0]}ms, great: ±${windowsMs[1]}ms, good: ±${windowsMs[2]}ms)';
  }
}

/// Motor de puntuación y estadísticas
class ScoreEngine {
  int totalScore = 0;
  int combo = 0;
  int maxCombo = 0;
  int hitCount = 0;
  int missCount = 0;

  // Contadores por calidad
  int perfectCount = 0;
  int greatCount = 0;
  int goodCount = 0;

  // Estadísticas
  List<int> deviations = []; // Desviaciones en ticks

  /// Registra un hit exitoso
  void recordHit(HitQuality quality) {
    if (quality == HitQuality.miss) {
      recordMiss();
      return;
    }

    final points = quality.getScore();
    totalScore += points;
    combo++;
    maxCombo = max(maxCombo, combo);
    hitCount++;

    // Contadores por calidad
    switch (quality) {
      case HitQuality.perfect:
        perfectCount++;
        break;
      case HitQuality.great:
        greatCount++;
        break;
      case HitQuality.good:
        goodCount++;
        break;
      case HitQuality.miss:
        break;
    }
  }

  /// Registra un fallo (nota perdida)
  void recordMiss() {
    combo = 0;
    missCount++;
  }

  /// Registra una desviación en ticks
  void recordDeviation(int deviationTicks) {
    deviations.add(deviationTicks);
  }

  /// Calcula el porcentaje de precisión
  double getAccuracy() {
    final total = hitCount + missCount;
    return total > 0 ? (hitCount / total) * 100 : 0.0;
  }

  /// Calcula la desviación promedio en ticks
  int getAverageDeviation() {
    if (deviations.isEmpty) return 0;
    final sum = deviations.fold<int>(0, (prev, dev) => prev + dev.abs());
    return (sum / deviations.length).toInt();
  }

  /// Calcula la desviación estándar
  double getDeviationStdDev() {
    if (deviations.length < 2) return 0.0;

    final mean = getAverageDeviation().toDouble();
    double sumSquaredDiff = 0;

    for (var dev in deviations) {
      final diff = dev.abs() - mean;
      sumSquaredDiff += diff * diff;
    }

    return sqrt(sumSquaredDiff / deviations.length);
  }

  /// Reinicia todas las estadísticas
  void reset() {
    totalScore = 0;
    combo = 0;
    maxCombo = 0;
    hitCount = 0;
    missCount = 0;
    perfectCount = 0;
    greatCount = 0;
    goodCount = 0;
    deviations.clear();
  }

  /// Obtiene un resumen de las estadísticas
  ScoreSummary getSummary() {
    return ScoreSummary(
      totalScore: totalScore,
      accuracy: getAccuracy(),
      combo: combo,
      maxCombo: maxCombo,
      hitCount: hitCount,
      missCount: missCount,
      perfectCount: perfectCount,
      greatCount: greatCount,
      goodCount: goodCount,
      averageDeviation: getAverageDeviation(),
      deviationStdDev: getDeviationStdDev(),
    );
  }

  @override
  String toString() {
    final summary = getSummary();
    return '''
    Score Engine Summary:
    - Total Score: $totalScore
    - Accuracy: ${summary.accuracy.toStringAsFixed(1)}%
    - Combo: $combo / $maxCombo
    - Hits: $hitCount / Misses: $missCount
    - Perfect: $perfectCount, Great: $greatCount, Good: $goodCount
    - Avg Deviation: ${summary.averageDeviation}ms
    ''';
  }
}

/// Resumen de puntuación y estadísticas
class ScoreSummary {
  final int totalScore;
  final double accuracy;
  final int combo;
  final int maxCombo;
  final int hitCount;
  final int missCount;
  final int perfectCount;
  final int greatCount;
  final int goodCount;
  final int averageDeviation;
  final double deviationStdDev;

  ScoreSummary({
    required this.totalScore,
    required this.accuracy,
    required this.combo,
    required this.maxCombo,
    required this.hitCount,
    required this.missCount,
    required this.perfectCount,
    required this.greatCount,
    required this.goodCount,
    required this.averageDeviation,
    required this.deviationStdDev,
  });

  /// Califica el desempeño general
  String getGrade() {
    if (accuracy >= 95) return 'S'; // Excelente
    if (accuracy >= 85) return 'A'; // Muy bueno
    if (accuracy >= 75) return 'B'; // Bueno
    if (accuracy >= 65) return 'C'; // Aceptable
    return 'D'; // Necesita mejorar
  }

  @override
  String toString() {
    return '''
    Score Summary:
    - Grade: ${getGrade()}
    - Total Score: $totalScore
    - Accuracy: ${accuracy.toStringAsFixed(1)}%
    - Max Combo: $maxCombo
    - Hits/Misses: $hitCount/$missCount
    - Perfect/Great/Good: $perfectCount/$greatCount/$goodCount
    ''';
  }
}
