/// Representación de métrica (Time Signature) musical
class TimeSignature {
  final int numerator;    // Beats por compás (arriba)
  final int denominator;  // Tipo de figura (abajo)

  const TimeSignature(this.numerator, this.denominator)
      : assert(numerator > 0, 'numerator debe ser mayor a 0'),
        assert(denominator > 0, 'denominator debe ser mayor a 0');

  /// Retorna los ticks por compás (TPQN = 480)
  /// Ejemplo: 4/4 = 1920 ticks (4 negras = 4 × 480)
  int getTicksPerMeasure() {
    // El denominador especifica la figura base
    // 4 = quarter note (negra), 8 = eighth note (corchea), etc.
    const tpqn = 480; // Ticks per Quarter Note
    
    // Calcular cuántos ticks tiene la figura denominador
    final beatTypeValue = (4 / denominator) * tpqn;
    
    // Multiplicar por el número de beats
    return (numerator * beatTypeValue).toInt();
  }

  /// Verifica si esta métrica necesita anacrusa (pickup)
  /// dado un tiempo de viaje en ticks
  bool needsPickup(int travelTicks) {
    final ticksPerMeasure = getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    return remainder != 0;
  }

  /// Calcula los ticks de anacrusa necesarios
  /// Ejemplo: 3/4 con 8 beats de viaje (3840 ticks)
  /// 3840 % 1440 = 720 → anacrusa = 1440 - 720 = 720 ticks
  int getPickupTicks(int travelTicks) {
    final ticksPerMeasure = getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    if (remainder == 0) return 0;
    return ticksPerMeasure - remainder;
  }

  /// Obtiene el numerador en formato legible
  String get numeratorDisplay => numerator.toString();

  /// Obtiene el denominador en formato legible
  String get denominatorDisplay => denominator.toString();

  /// Representación en string
  @override
  String toString() => '$numerator/$denominator';

  /// Comparación de igualdad
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          runtimeType == other.runtimeType &&
          numerator == other.numerator &&
          denominator == other.denominator;

  @override
  int get hashCode => numerator.hashCode ^ denominator.hashCode;

  /// Copia con cambios específicos
  TimeSignature copyWith({
    int? numerator,
    int? denominator,
  }) {
    return TimeSignature(
      numerator ?? this.numerator,
      denominator ?? this.denominator,
    );
  }

  /// Métricas comunes predefinidas
  static const TimeSignature common_4_4 = TimeSignature(4, 4);
  static const TimeSignature common_3_4 = TimeSignature(3, 4);
  static const TimeSignature common_2_4 = TimeSignature(2, 4);
  static const TimeSignature common_6_8 = TimeSignature(6, 8);
  static const TimeSignature common_2_2 = TimeSignature(2, 2);
  static const TimeSignature common_5_4 = TimeSignature(5, 4);

  /// Lista de métricas comunes
  static const List<TimeSignature> commonTimeSignatures = [
    common_4_4,
    common_3_4,
    common_2_4,
    common_6_8,
    common_2_2,
    common_5_4,
  ];
}
