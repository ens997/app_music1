import 'dart:math';
import 'enumerations.dart';

/// Modelo que representa una nota individual en la secuencia musical
class NoteModel {
  final String pitch; // "C4", "D#5", "Bb3", etc.
  final NoteDuration duration; // whole, half, quarter, etc.
  final int absoluteTick; // Posicion en ticks absoluta
  final int durationTicks; // Duracion real en ticks
  final bool isDotted; // Nota con puntillo
  final int velocity; // MIDI velocity (0-127), default 64
  final bool isRest; // true si es silencio/pausa
  final Accidental accidental; // sharp, flat, natural, etc.
  final bool displayAccidental; // true si debe mostrarse accidental en notacion
  final BeamType beamType; // begin, continue, end, none
  final Map<int, BeamType> beamLevels; // 1=corchea, 2=semicorchea, etc.

  // Estado durante el juego
  late int targetTick; // Cuando debe sonar (calculado + offset)
  late int? hitTick; // Cuando fue golpeada
  bool isHit = false;
  bool isMissed = false;
  HitQuality? hitQuality;
  int? hitDeviationTicks; // Desviacion en ticks respecto al target

  NoteModel({
    required this.pitch,
    required this.duration,
    required this.absoluteTick,
    int? durationTicksOverride,
    this.isDotted = false,
    this.velocity = 64,
    this.isRest = false,
    this.accidental = Accidental.natural,
    this.displayAccidental = false,
    this.beamType = BeamType.none,
    Map<int, BeamType>? beamLevels,
  }) : beamLevels = Map.unmodifiable(beamLevels ?? <int, BeamType>{}),
       durationTicks = durationTicksOverride ?? duration.getTicksAtTPQN480() {
    // Inicializar target tick igual a absolute tick
    // Se ajustara en GameSession segun la logica de viaje visual
    targetTick = absoluteTick;
  }

  /// Extrae el nombre de la nota sin alteracion ni octava
  String get noteName {
    return pitch.substring(0, 1);
  }

  /// Extrae la octava de la nota
  int get octave {
    try {
      final match = RegExp(r'-?\d+').firstMatch(pitch);
      if (match != null) {
        return int.parse(match.group(0)!);
      }
    } catch (e) {
      // Default a octava 4
    }
    return 4;
  }

  /// Obtiene la frecuencia en Hz (para sintesis de audio)
  /// Usa la formula: f = 440 * 2^((n-69)/12)
  double getFrequency() {
    final midiNumber = getMidiNumber();
    return 440 * pow(2, (midiNumber - 69) / 12) as double;
  }

  /// Obtiene numero MIDI (0-127)
  /// La4 (440 Hz) = MIDI 69
  int getMidiNumber() {
    const noteToPitch = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    final noteNameFirst = pitch.substring(0, 1);
    int basePitch = noteToPitch[noteNameFirst] ?? 0;

    if (pitch.contains('#')) basePitch += 1;
    if (pitch.contains('b')) basePitch -= 1;

    return (octave + 1) * 12 + basePitch;
  }

  /// Calcula desviacion en ticks respecto al tiempo target
  /// Negativo = adelantado, Positivo = atrasado
  int getDeviationTicks(int currentTick) {
    return currentTick - targetTick;
  }

  /// Marca esta nota como golpeada con la calidad especificada
  void markAsHit(HitQuality quality, int currentTick) {
    isHit = true;
    isMissed = false;
    hitQuality = quality;
    hitTick = currentTick;
    hitDeviationTicks = getDeviationTicks(currentTick);
  }

  /// Marca esta nota como perdida (no golpeada a tiempo)
  void markAsMissed() {
    isHit = false;
    isMissed = true;
    hitQuality = HitQuality.miss;
  }

  /// Reinicia el estado de la nota
  void reset() {
    isHit = false;
    isMissed = false;
    hitQuality = null;
    hitTick = null;
    hitDeviationTicks = null;
  }

  /// Copia con cambios especificos
  NoteModel copyWith({
    String? pitch,
    NoteDuration? duration,
    int? durationTicksOverride,
    int? absoluteTick,
    bool? isDotted,
    int? velocity,
    bool? isRest,
    Accidental? accidental,
    bool? displayAccidental,
    BeamType? beamType,
    Map<int, BeamType>? beamLevels,
  }) {
    return NoteModel(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      durationTicksOverride: durationTicksOverride ?? durationTicks,
      absoluteTick: absoluteTick ?? this.absoluteTick,
      isDotted: isDotted ?? this.isDotted,
      velocity: velocity ?? this.velocity,
      isRest: isRest ?? this.isRest,
      accidental: accidental ?? this.accidental,
      displayAccidental: displayAccidental ?? this.displayAccidental,
      beamType: beamType ?? this.beamType,
      beamLevels: beamLevels ?? this.beamLevels,
    );
  }

  @override
  String toString() =>
      'Note($pitch, dur=${duration.displayName}, tick=$absoluteTick, ${hitQuality?.displayName ?? "pending"})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteModel &&
          runtimeType == other.runtimeType &&
          pitch == other.pitch &&
          duration == other.duration &&
          durationTicks == other.durationTicks &&
          absoluteTick == other.absoluteTick &&
          isDotted == other.isDotted &&
          accidental == other.accidental &&
          displayAccidental == other.displayAccidental;

  @override
  int get hashCode =>
      pitch.hashCode ^
      duration.hashCode ^
      durationTicks.hashCode ^
      absoluteTick.hashCode ^
      isDotted.hashCode ^
      accidental.hashCode ^
      displayAccidental.hashCode;
}
