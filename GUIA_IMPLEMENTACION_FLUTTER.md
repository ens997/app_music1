# Guía de Implementación Flutter - App de Enseñanza Musical

## 📐 Diagrama de Clases - Musical Engine

```
┌────────────────────────────────────────────────┐
│           TicksEngine (Core)                   │
├────────────────────────────────────────────────┤
│ - tpqn: int = 480                             │
│ - currentTick: int                            │
│ - bpm: int                                     │
│ - isPlaying: bool                             │
├────────────────────────────────────────────────┤
│ + getNoteTickDuration(NoteDuration): int      │
│ + calculateTicksPerMeasure(TimeSignature): int│
│ + ticksToMilliseconds(int ticks): Duration    │
│ + msToTicks(int ms): int                      │
│ + getFrequency(String pitch): double          │
└────────────────────────────────────────────────┘
          △                          △
          │                          │
          │                          │
┌─────────────────────────┐  ┌──────────────────────────┐
│  TimeSignature          │  │  NoteModel                │
├─────────────────────────┤  ├──────────────────────────┤
│ - numerator: int        │  │ - pitch: String (C4)     │
│ - denominator: int      │  │ - duration: NoteDuration │
├─────────────────────────┤  │ - absoluteTick: int      │
│ + getTicksPerMeasure()  │  │ - durationTicks: int     │
│ + needsPickup()         │  │ - velocity: int          │
└─────────────────────────┘  │ - isRest: bool           │
                              ├──────────────────────────┤
                              │ + getFrequency(): double │
                              │ + getMidiNumber(): int   │
                              └──────────────────────────┘

┌─────────────────────────────────────────┐
│     PickupCalculator (Static)           │
├─────────────────────────────────────────┤
│ + calculatePickupTicks(                 │
│     int travelTicks,                    │
│     int ticksPerMeasure): int           │
│ + isAnacrusicMeasure(                   │
│     int measureNumber): bool            │
└─────────────────────────────────────────┘

┌──────────────────────────────────────┐
│     HitWindow                        │
├──────────────────────────────────────┤
│ - perfect: int = 48 ticks (100ms)    │
│ - great: int = 96 ticks (200ms)      │
│ - good: int = 144 ticks (300ms)      │
├──────────────────────────────────────┤
│ + getQuality(int deviationTicks)     │
│   → HitQuality                       │
└──────────────────────────────────────┘
```

## 📐 Diagrama de Clases - Visual Engine

```
┌──────────────────────────────────────────────┐
│  SMuFLRenderer extends CustomPainter         │
├──────────────────────────────────────────────┤
│ - score: MusicScore                         │
│ - ticksEngine: TicksEngine                  │
│ - visibleNotes: List<NoteModel>            │
│ - animationManager: AnimationManager        │
├──────────────────────────────────────────────┤
│ + paint(Canvas, Size): void                 │
│ + shouldRepaint(SMuFLRenderer): bool        │
└──────────────────────────────────────────────┘
                    △
                    │ usa
       ┌────────────┼────────────┐
       ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌────────────────────┐
│StaffRenderer │ │NoteVisual    │ │AnimationManager    │
├──────────────┤ ├──────────────┤ ├────────────────────┤
│ + drawStaff()│ │ + getNoteHead│ │ - feedbackAnim[]   │
│ + drawClef() │ │ + drawStem() │ │ - comboAnim[]      │
│ + drawBarLine│ │ + drawBeam() │ │ - accuracyAnim[]   │
└──────────────┘ └──────────────┘ ├────────────────────┤
                                   │ + addHitFeedback() │
                                   │ + updateAndDraw()  │
                                   └────────────────────┘
```

## 📐 Diagrama de Clases - Game Logic

```
┌──────────────────────────────────────────────┐
│  GameSession                                  │
├──────────────────────────────────────────────┤
│ - ticksEngine: TicksEngine                  │
│ - renderer: SMuFLRenderer                   │
│ - scoreEngine: ScoreEngine                  │
│ - metronome: MetronomeController            │
│ - currentTick: int                          │
│ - isPlaying: bool                           │
├──────────────────────────────────────────────┤
│ + start(): void                             │
│ + pause(): void                             │
│ + stop(): void                              │
│ + handleUserInput(): void                   │
│ + reset(): void                             │
└──────────────────────────────────────────────┘
      │uses         │uses       │uses       │uses
      ▼             ▼           ▼           ▼
┌──────────┐  ┌──────────┐  ┌────────┐  ┌──────────────┐
│TicksEng. │  │ScoreEng. │  │Metron. │  │InputHandler  │
└──────────┘  └──────────┘  └────────┘  └──────────────┘
```

## 💻 Ejemplos de Código Iniciales

### 1. Enumeraciones Base

```dart
// lib/core/models/note_duration.dart
enum NoteName { C, D, E, F, G, A, B }

enum NoteDuration {
  whole,        // 4 beats = 1920 ticks
  half,         // 2 beats = 960 ticks
  quarter,      // 1 beat = 480 ticks
  eighth,       // 0.5 beat = 240 ticks
  sixteenth;    // 0.25 beat = 120 ticks
  
  int getTicksAtTPQN480() {
    switch (this) {
      case NoteDuration.whole:
        return 1920;
      case NoteDuration.half:
        return 960;
      case NoteDuration.quarter:
        return 480;
      case NoteDuration.eighth:
        return 240;
      case NoteDuration.sixteenth:
        return 120;
    }
  }
}

enum HitQuality { perfect, great, good, miss }

enum ClefType { treble, bass, alto }

enum Accidental { natural, sharp, flat, doubleSharp, doubleFlat }
```

### 2. TimeSignature

```dart
// lib/core/models/time_signature.dart
class TimeSignature {
  final int numerator;    // Beats per measure
  final int denominator;  // Note value
  
  const TimeSignature(this.numerator, this.denominator)
    : assert(numerator > 0),
      assert(denominator > 0);
  
  /// Retorna los ticks por compás (TPQN = 480)
  int getTicksPerMeasure() {
    // El denominador especifica la figura
    // 4 = quarter note, 8 = eighth note, etc.
    final beatValue = 480; // TPQN
    final beatTypeValue = (4 / denominator) * beatValue;
    return (numerator * beatTypeValue).toInt();
  }
  
  /// Ejemplo: 4/4 con 8 beats de viaje
  /// 8 beats = 8 × 480 = 3840 ticks
  /// 3840 % 1920 (ticks of 4/4) = 0 → NO anacrusa
  bool needsPickup(int travelTicks) {
    final ticksPerMeasure = getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    return remainder != 0;
  }
  
  int getPickupTicks(int travelTicks) {
    final ticksPerMeasure = getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    if (remainder == 0) return 0;
    return ticksPerMeasure - remainder;
  }
  
  @override
  String toString() => '$numerator/$denominator';
}
```

### 3. TicksEngine

```dart
// lib/core/musical_engine/ticks_engine.dart
class TicksEngine {
  static const int TPQN = 480; // Ticks Per Quarter Note
  
  int _bpm = 120;
  late Stopwatch _timer;
  int _currentTick = 0;
  
  int get bpm => _bpm;
  int get currentTick => _currentTick;
  bool get isRunning => _timer.isRunning;
  
  TicksEngine({int initialBpm = 120}) : _bpm = initialBpm {
    _timer = Stopwatch();
  }
  
  /// Establece el tempo en BPM
  void setBpm(int newBpm) {
    if (newBpm < 30 || newBpm > 300) {
      throw ArgumentError('BPM debe estar entre 30 y 300');
    }
    _bpm = newBpm;
  }
  
  /// Duración de un quarter note en millisegundos
  double getQuarterNoteDuration() {
    return 60000 / _bpm; // 500ms para 120 BPM
  }
  
  /// Convierte ticks a millisegundos
  double ticksToMilliseconds(int ticks) {
    return (ticks / TPQN) * getQuarterNoteDuration();
  }
  
  /// Convierte millisegundos a ticks
  int millisecondsToTicks(double ms) {
    return (ms * TPQN / getQuarterNoteDuration()).toInt();
  }
  
  /// Comienza el reloj
  void start() {
    _timer.start();
  }
  
  /// Pausa el reloj
  void pause() {
    _timer.stop();
  }
  
  /// Reinicia el reloj
  void reset() {
    _timer.reset();
    _currentTick = 0;
  }
  
  /// Actualiza el tick actual basado en tiempo transcurrido
  void update() {
    if (!_timer.isRunning) return;
    _currentTick = millisecondsToTicks(_timer.elapsedMilliseconds.toDouble()).toInt();
  }
  
  /// Obtiene duración de una nota en ticks
  static int getNoteDurationTicks(NoteDuration duration) {
    return duration.getTicksAtTPQN480();
  }
}
```

### 4. NoteModel

```dart
// lib/core/models/note_model.dart
class NoteModel {
  final String pitch;              // "C4", "D#5", "Bb3", etc.
  final NoteDuration duration;     // whole, half, quarter, etc.
  final int absoluteTick;          // Posición en ticks absoluta
  final int durationTicks;         // Duración en ticks
  final int velocity;              // MIDI velocity (0-127)
  final bool isRest;               // true si es silencio
  final Accidental accidental;     // sharp, flat, natural, etc.
  
  late int targetTick;             // Cuando debe sonar
  late int hitTick;                // Cuando fue golpeada
  bool isHit = false;
  bool isMissed = false;
  HitQuality? hitQuality;
  
  NoteModel({
    required this.pitch,
    required this.duration,
    required this.absoluteTick,
    this.velocity = 64,
    this.isRest = false,
    this.accidental = Accidental.natural,
  }) : durationTicks = duration.getTicksAtTPQN480();
  
  /// Obtiene la frecuencia en Hz (para síntesis de audio)
  double getFrequency() {
    final midiNumber = getMidiNumber();
    // f = 440 * 2^((n-69)/12)
    return 440 * pow(2, (midiNumber - 69) / 12) as double;
  }
  
  /// Obtiene número MIDI (0-127)
  int getMidiNumber() {
    const noteToPitch = {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11
    };
    
    final noteName = pitch.substring(0, 1);
    final octave = int.parse(pitch.substring(1));
    int basePitch = noteToPitch[noteName] ?? 0;
    
    // Aplicar accidentes
    if (pitch.contains('#')) basePitch += 1;
    if (pitch.contains('b')) basePitch -= 1;
    
    return (octave + 1) * 12 + basePitch;
  }
  
  /// Calcula desviación en ticks respecto al tiempo target
  int getDeviationTicks(int currentTick) {
    return currentTick - targetTick;
  }
  
  @override
  String toString() => 'Note($pitch, dur=$duration, tick=$absoluteTick)';
}
```

### 5. HitWindow & Scoring

```dart
// lib/core/musical_engine/hit_window.dart
class HitWindow {
  final TicksEngine engine;
  
  // Ventanas en ticks (a 120 BPM)
  late int perfectWindow;
  late int greatWindow;
  late int goodWindow;
  
  HitWindow(this.engine) {
    _updateWindows();
  }
  
  void _updateWindows() {
    // Las ventanas son en milisegundos reales
    // Convertimos a ticks basados en BPM actual
    const perfectMs = 50;   // ±50ms
    const greatMs = 100;    // ±100ms
    const goodMs = 150;     // ±150ms
    
    perfectWindow = engine.millisecondsToTicks(perfectMs.toDouble());
    greatWindow = engine.millisecondsToTicks(greatMs.toDouble());
    goodWindow = engine.millisecondsToTicks(goodMs.toDouble());
  }
  
  HitQuality getQuality(int deviationTicks) {
    final absDev = deviationTicks.abs();
    
    if (absDev <= perfectWindow) return HitQuality.perfect;
    if (absDev <= greatWindow) return HitQuality.great;
    if (absDev <= goodWindow) return HitQuality.good;
    return HitQuality.miss;
  }
  
  int getScore(HitQuality quality) {
    switch (quality) {
      case HitQuality.perfect:
        return 300;
      case HitQuality.great:
        return 200;
      case HitQuality.good:
        return 100;
      case HitQuality.miss:
        return 0;
    }
  }
}

class ScoreEngine {
  int totalScore = 0;
  int combo = 0;
  int maxCombo = 0;
  int hitCount = 0;
  int missCount = 0;
  
  void recordHit(HitQuality quality) {
    final points = HitWindow(TicksEngine()).getScore(quality);
    totalScore += points;
    combo++;
    maxCombo = max(maxCombo, combo);
    hitCount++;
  }
  
  void recordMiss() {
    combo = 0;
    missCount++;
  }
  
  double getAccuracy() {
    final total = hitCount + missCount;
    return total > 0 ? (hitCount / total) * 100 : 0;
  }
}
```

### 6. PickupCalculator

```dart
// lib/core/musical_engine/pickup_calculator.dart
class PickupCalculator {
  /// Calcula beats de anacrusa necesarios
  static int calculatePickupTicks(
    int travelTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    
    if (remainder == 0) return 0; // Múltiplo exacto, sin anacrusa
    
    return ticksPerMeasure - remainder;
  }
  
  /// Ejemplo: 3/4 con 8 beats de viaje
  /// 8 beats = 3840 ticks
  /// ticksPerMeasure = 1440 (3/4)
  /// 3840 % 1440 = 720
  /// pickup = 1440 - 720 = 720 ticks (1.5 beats)
  static bool needsAnacrusis(
    int travelTicks,
    TimeSignature timeSignature,
  ) {
    final ticksPerMeasure = timeSignature.getTicksPerMeasure();
    final remainder = travelTicks % ticksPerMeasure;
    return remainder != 0;
  }
}
```

## 📦 Pubspec.yaml Recomendado

```yaml
name: music_training_app
description: App educativa para entrenamiento musical con soporte MusicXML

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Audio
  audioplayers: ^5.2.0          # Para síntesis de sonido
  
  # Fuentes
  google_fonts: ^6.0.0           # Incluye SMuFL fonts
  
  # MusicXML parsing
  xml: ^6.3.0                    # Parsing XML basic
  
  # File handling
  file_picker: ^6.0.0            # Seleccionar archivos
  
  # Audio synthesis
  flutter_sound: ^9.0.0          # Síntesis avanzada (opcional)

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  flutter_linter: ^2.0.0
  test: ^1.24.0
```

## 🎯 Checklist de Implementación

- [ ] 1. Setup proyecto Flutter con estructura modular
- [ ] 2. Implementar TicksEngine (core temporal)
- [ ] 3. Implementar TimeSignature y conversiones
- [ ] 4. Implementar NoteModel
- [ ] 5. Implementar PickupCalculator
- [ ] 6. Implementar HitWindow y ScoreEngine
- [ ] 7. StaffRenderer (dibujar pentagrama)
- [ ] 8. NoteVisual (dibujar notas con SMuFL)
- [ ] 9. AnimationManager
- [ ] 10. MusicXML Parser
- [ ] 11. GameSession orquestador
- [ ] 12. MetronomeController
- [ ] 13. UI principal (GameScreen)
- [ ] 14. Configuración (SettingsScreen)
- [ ] 15. File picker (MusicXML importer)

---

**Próximo paso: Crear el proyecto Flutter y comenzar con la implementación del TicksEngine**
