import '../models/models.dart';

/// Calcula automáticamente la anacrusa (pickup) necesaria
/// para sincronizar el metrónomo con la llegada de las notas
class PickupCalculator {
  /// Calcula ticks de anacrusa necesarios
  /// Ejemplo: 3/4 con 8 beats (3840 ticks) de viaje
  /// ticksPerMeasure = 1440 (3/4)
  /// 3840 % 1440 = 720
  /// anacrusa = 1440 - 720 = 720 ticks (1.5 beats)
  static int calculatePickupTicks(
    int travelTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;

    // Si es múltiplo exacto, no hay anacrusa necesaria
    if (remainder == 0) return 0;

    // Calcular beats faltantes para completar la medida
    return ticksPerMeasure - remainder;
  }

  /// Verifica si esta combinación de viaje y métrica necesita anacrusa
  static bool needsAnacrusis(
    int travelTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    return remainder != 0;
  }

  /// Convierte ticks de anacrusa a beats
  static double pickupTicksToBeats(
    int pickupTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    return (pickupTicks / (ticksPerMeasure / timeSignature.numerator));
  }

  /// Obtiene información detallada de la anacrusa
  static PickupInfo getPickupInfo(
    int travelTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    final pickupTicks = remainder == 0 ? 0 : ticksPerMeasure - remainder;

    return PickupInfo(
      needsPickup: remainder != 0,
      pickupTicks: pickupTicks,
      pickupBeats: pickupTicksToBeats(pickupTicks, timeSignature),
      travelTicks: travelTicks,
      ticksPerMeasure: ticksPerMeasure,
      remainder: remainder,
    );
  }
}

/// Información detallada sobre la anacrusa requerida
class PickupInfo {
  final bool needsPickup;
  final int pickupTicks;
  final double pickupBeats;
  final int travelTicks;
  final int ticksPerMeasure;
  final int remainder;

  PickupInfo({
    required this.needsPickup,
    required this.pickupTicks,
    required this.pickupBeats,
    required this.travelTicks,
    required this.ticksPerMeasure,
    required this.remainder,
  });

  @override
  String toString() {
    return '''
    Pickup Info:
    - Needs Pickup: $needsPickup
    - Pickup Ticks: $pickupTicks
    - Pickup Beats: ${pickupBeats.toStringAsFixed(2)}
    - Travel Ticks: $travelTicks
    - Ticks per Measure: $ticksPerMeasure
    - Remainder: $remainder
    ''';
  }
}
