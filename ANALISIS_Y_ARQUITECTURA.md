# Análisis del Prototipo y Arquitectura Flutter para App de Enseñanza Musical

## 📋 ANÁLISIS DEL PROTOTIPO HTML

### Concepto General
**"Entrenador Rítmico Pro - Sistema de Anacrusa"** es una aplicación interactiva educativa que:
- Entrena sincronización rítmica mediante notas visuales que viajan por la pantalla
- Mide precisión con ventanas de hit (Perfect, Great, Good)
- Utiliza un **sistema de anacrusa** para sincronizar el metrónomo con la llegada de notas
- Soporta múltiples métricas (4/4, 3/4, 2/4)
- Control dinámico de tempo (60-180 BPM)

### Componentes Principales del Prototipo

#### 1️⃣ **ProfessionalRhythmEngine** (Motor de Lógica Musical)
Gestiona:
- **Timing**: BPM, Beat Duration, Measure Duration
- **Time Signatures**: Métricas (numerador/denominador)
- **Hit Windows**: Ventanas de precisión temporal
  ```
  Perfect: ±50ms
  Great:   ±100ms
  Good:    ±150ms
  Miss:    >150ms
  ```
- **Anacrusa (Pickup)**: Sistema para sincronizar metrónomo
  ```
  Cálculo: beats_anacrusa = (medida - (travelBeats % medida)) % medida
  Ejemplo: 3/4 con 8 beats de viaje → 8 % 3 = 2 → anacrusa = 2 beats
  ```
- **Note Sequencing**: Generación de secuencias con timing exacto
- **Scoring**: Puntuación, combo, accuracy

#### 2️⃣ **CanvasRenderer** (Sistema Visual)
Renderiza:
- Pentagrama (5 líneas + espacios)
- Clave de Sol
- Indicación de compás
- Notas musicales (blancas, negras, con punto)
- Línea roja de "hit" (target line)
- Animaciones de feedback (radiantes, combo, precisión)

#### 3️⃣ **Audio System**
- Metrónomo con acentos (beat 1 más fuerte)
- Sonidos de notas (síntesis de audio Web Audio API)
- Control de volumen

---

## 🏗️ ARQUITECTURA PROPUESTA PARA FLUTTER

### Separación de Sistemas

```
┌─────────────────────────────────────────────────────┐
│               APLICACIÓN FLUTTER                     │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │   UI Layer (Widgets Flutter)                 │   │
│  │  - GameScreen, SettingsScreen, etc.         │   │
│  └──────────────┬───────────────────────────────┘   │
│                 │                                   │
│  ┌──────────────────────────┐  ┌────────────────┐  │
│  │ VISUAL ENGINE (SMuFL)    │  │ MUSICAL ENGINE │  │
│  │──────────────────────────│  │ (TPQN 480)     │  │
│  │ - SMuFLRenderer          │  │────────────────│  │
│  │ - StaffRenderer          │  │ - TicksEngine  │  │
│  │ - NoteVisual             │  │ - TimeSignature│  │
│  │ - AnimationManager       │  │ - NoteModel    │  │
│  │ - FeedbackAnimations     │  │ - TempoCalc    │  │
│  └──────────────┬───────────┘  │ - PickupCalc   │  │
│                 │              │ - HitWindow    │  │
│                 │              └────────┬────────┘  │
│                 │                       │           │
│  ┌──────────────────────────────────────┴────────┐  │
│  │   Game Logic Orchestration                     │  │
│  │  - GameSession (orquesta todo)                │  │
│  │  - ScoreEngine                                │  │
│  │  - MetronomeController                        │  │
│  │  - InputHandler                               │  │
│  └──────────────┬─────────────────────────────────┘  │
│                 │                                   │
│  ┌──────────────────────────────────────────────┐   │
│  │  MusicXML Parser & Data Layer                │   │
│  │  - MusicXMLParser                            │   │
│  │  - PartHandler, MeasureHandler               │   │
│  │  - NoteExtractor → Internal Format           │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 📊 SYSTEM 1: MUSICAL LOGIC ENGINE (Basado en TPQN 480)

### Concepto: Ticks Per Quarter Note (TPQN)
Standard en MIDI y MusicXML. **1 Quarter Note = 480 Ticks**

### Conversiones Fundamentales
```dart
const TPQN = 480;  // Ticks per Quarter Note (estándar MIDI)

// Duraciones base
const TICKS_WHOLE = 1920;      // 4 × 480
const TICKS_HALF = 960;        // 2 × 480
const TICKS_QUARTER = 480;     // 1 × 480
const TICKS_EIGHTH = 240;      // 0.5 × 480
const TICKS_SIXTEENTH = 120;   // 0.25 × 480

// Duración con punto (1.5×)
const TICKS_DOTTED_HALF = 1440;      // 960 × 1.5
const TICKS_DOTTED_QUARTER = 720;    // 480 × 1.5

// Conversión BPM → Milliseconds
milliseconds = (TICKS_QUARTER / bpm) * 1000 / 60
             = (480 / 120) * 1000 / 60
             = 500 ms (para 120 BPM)
```

### Estructura de Clases

#### 1. **TicksEngine** (Core Temporal)
```dart
class TicksEngine {
  final int tpqn = 480;
  late int currentTick;
  late int bpm;
  
  int getNoteTickDuration(NoteDuration duration) {
    // Retorna la duración en TPQN
  }
  
  int calculateTicksPerMeasure(TimeSignature ts) {
    // 4/4 → 1920 ticks (4 × 480)
    // 3/4 → 1440 ticks (3 × 480)
  }
  
  Duration ticksToMilliseconds(int ticks) {
    // Convierte ticks a tiempo real considerando BPM
  }
}
```

#### 2. **TimeSignature**
```dart
class TimeSignature {
  final int numerator;    // Beats por compás (arriba)
  final int denominator;  // Tipo de figura (abajo)
  
  int getTicksPerMeasure(int tpqn) {
    // BPM 120: 4/4 = 2000ms, 3/4 = 1500ms
  }
  
  bool needsPickup(int travelTicks) {
    // Calcula si necesita anacrusa
    return (travelTicks % getTicksPerMeasure(tpqn)) != 0;
  }
}
```

#### 3. **NoteModel**
```dart
class NoteModel {
  final String pitch;           // "C4", "D#5", etc.
  final NoteDuration duration;  // whole, half, quarter, eighth
  final int absoluteTick;       // Posición absoluta en TPQN
  final int durationTicks;      // Duración en TPQN
  
  int getFrequency() => noteToFrequency(pitch);
  bool isDotted() => duration.isDotted;
}
```

#### 4. **PickupCalculator**
```dart
class PickupCalculator {
  static int calculatePickupTicks(
    int travelTicks,
    int ticksPerMeasure,
  ) {
    int remainder = travelTicks % ticksPerMeasure;
    if (remainder == 0) return 0;
    return ticksPerMeasure - remainder;
  }
  
  // Para 3/4 con 8 beats (3840 ticks):
  // 3840 % 1440 = 720 ticks (1.5 beats)
  // anacrusa = 1440 - 720 = 720 ticks (1.5 beats)
}
```

#### 5. **HitWindow & Scoring**
```dart
class HitWindow {
  final int perfect = 48;    // 100ms a 120 BPM
  final int great = 96;      // 200ms a 120 BPM
  final int good = 144;      // 300ms a 120 BPM
  
  HitQuality getQuality(int deviationTicks) {
    if (deviationTicks.abs() <= perfect) return Perfect;
    if (deviationTicks.abs() <= great) return Great;
    if (deviationTicks.abs() <= good) return Good;
    return Miss;
  }
}
```

---

## 🎨 SYSTEM 2: VISUAL ENGINE (SMuFL - Standard Music Font Layout)

### Concepto: SMuFL
Font estándar para notación musical (como Unicode para música). Incluye:
- Notas (whole, half, quarter, eighth, sixteenth)
- Silencios
- Claves (Sol, Fa, Do)
- Compases
- Alteraciones (sostenido, bemol, becuadro)
- Más de 2000 símbolos

### Librerías Recomendadas
```yaml
dependencies:
  # Para SMuFL
  google_fonts: ^6.0.0       # Incluye "Bravura" (SMuFL)
  
  # Para renderizado personalizado
  flutter_canvas: usamos Canvas nativo
  custom_paint: para dibujos avanzados
```

### Estructura de Clases

#### 1. **SMuFLRenderer** (Dibujador Principal)
```dart
class SMuFLRenderer extends CustomPainter {
  final MusicScore score;
  final TicksEngine ticksEngine;
  final List<NoteModel> visibleNotes;
  
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar pentagrama
    drawStaff(canvas, size);
    
    // 2. Dibujar claves y compases
    drawClef(canvas);
    drawTimeSignature(canvas);
    
    // 3. Dibujar notas
    for (var note in visibleNotes) {
      drawNote(canvas, note);
    }
    
    // 4. Dibujar línea de hit
    drawHitLine(canvas, size);
  }
}
```

#### 2. **StaffRenderer**
```dart
class StaffRenderer {
  static final int LINE_COUNT = 5;
  static final double SPACE_HEIGHT = 14.0;
  
  static void drawStaff(Canvas canvas, Rect bounds) {
    // Dibuja 5 líneas del pentagrama
  }
  
  static void drawClef(Canvas canvas, Point position, ClefType clef) {
    // Dibuja clave de Sol/Fa/Do usando SMuFL
    // U+1D11E (Sol), U+1D11F (Fa), etc.
  }
  
  static void drawBarLine(Canvas canvas, Point position, bool isDouble) {
    // Dibuja línea de compás
  }
}
```

#### 3. **NoteVisual** (Mapeo Nota Lógica → Visual)
```dart
class NoteVisual {
  static const notePositions = {
    'C4': 10,   // 2 líneas debajo (con línea adicional)
    'D4': 9,
    'E4': 8,    // Línea 1
    'F4': 7,    // Espacio 1
    'G4': 6,    // Línea 2
    'A4': 5,    // Espacio 2
    'B4': 4,    // Línea 3
    'C5': 3,    // Espacio 3
  };
  
  static String getNoteHead(NoteDuration duration) {
    // Retorna código Unicode SMuFL
    // Half note: U+1D15B (○)
    // Quarter note: U+1D158 (●)
    // Whole note: U+1D15C
  }
  
  static Offset getStaffPosition(String pitch, double spaceHeight) {
    // Calcula posición Y en el pentagrama
  }
  
  static void drawStemAndBeam(Canvas canvas, Offset pos, NoteDuration duration) {
    // Dibuja plica y corchetes para notas cortas
  }
}
```

#### 4. **AnimationManager** (Feedback Visual)
```dart
class AnimationManager {
  List<HitFeedback> feedbackAnimations = [];
  List<ComboAnimation> comboAnimations = [];
  
  void addHitFeedback(Offset position, HitQuality quality) {
    feedbackAnimations.add(
      HitFeedback(
        position: position,
        quality: quality,
        startTime: DateTime.now(),
        duration: Duration(milliseconds: 800),
      ),
    );
  }
  
  void updateAndDraw(Canvas canvas, Duration elapsed) {
    for (var feedback in feedbackAnimations) {
      feedback.update(elapsed);
      feedback.draw(canvas);
      
      if (feedback.isComplete()) {
        feedbackAnimations.remove(feedback);
      }
    }
  }
}
```

---

## 📖 MusicXML Parser

### Ejemplo de Estructura XML
```xml
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.0">
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef><sign>G</sign></clef>
      </attributes>
      
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
```

### Parser Implementation
```dart
class MusicXMLParser {
  MusicScore parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    
    // Extraer información de compás y tempo
    final timeSignature = parseTimeSignature(document);
    final divisions = parseInt('divisions');
    
    // Iterar por notas
    final notes = <NoteModel>[];
    int currentTick = 0;
    
    for (var noteEl in document.findAllElements('note')) {
      final pitch = noteEl.findElements('pitch').single;
      final duration = int.parse(noteEl.findElements('duration').single.text);
      
      notes.add(NoteModel(
        pitch: '${pitch.findElements('step').first.text}${pitch.findElements('octave').first.text}',
        duration: durationFromDivisionsAndType(duration, divisions),
        absoluteTick: currentTick,
        durationTicks: convertToTicks(duration, divisions),
      ));
      
      currentTick += convertToTicks(duration, divisions);
    }
    
    return MusicScore(
      timeSignature: timeSignature,
      notes: notes,
      divisions: divisions,
    );
  }
}
```

---

## 🎮 Game Logic Layer

### Game Loop
```dart
class GameSession {
  final TicksEngine ticksEngine;
  final SMuFLRenderer renderer;
  final ScoreEngine scoreEngine;
  final MetronomeController metronome;
  
  late Stopwatch gameTimer;
  int currentTick = 0;
  
  void start() {
    gameTimer.start();
    _gameLoop();
  }
  
  void _gameLoop() {
    // Calcular tick actual basado en tiempo real + BPM
    final elapsedMs = gameTimer.elapsedMilliseconds;
    currentTick = msToTicks(elapsedMs);
    
    // Actualizar notas activas
    updateVisibleNotes();
    
    // Detectar colisiones con hit line
    detectNoteHits();
    
    // Actualizar UI
    notifyListeners();
    
    // Siguiente frame
    requestAnimationFrame(_gameLoop);
  }
  
  void handleUserInput() {
    // Buscar nota más cercana al hit line
    final bestNote = visibleNotes
      .where((n) => !n.isHit && !n.isMissed)
      .minBy((n) => (n.targetTick - currentTick).abs());
    
    if (bestNote != null) {
      final deviation = currentTick - bestNote.targetTick;
      scoreEngine.handleHit(bestNote, deviation);
    }
  }
}
```

---

## 📁 Estructura de Carpetas Recomendada

```
lib/
├── core/
│   ├── musical_engine/
│   │   ├── ticks_engine.dart
│   │   ├── time_signature.dart
│   │   ├── note_model.dart
│   │   ├── pickup_calculator.dart
│   │   ├── hit_window.dart
│   │   └── tempo_calculator.dart
│   │
│   └── models/
│       ├── music_score.dart
│       ├── note_duration.dart
│       ├── hit_quality.dart
│       └── clef_type.dart
│
├── visual_engine/
│   ├── smufl_renderer.dart
│   ├── staff_renderer.dart
│   ├── note_visual.dart
│   ├── animation_manager.dart
│   └── feedback_animations.dart
│
├── parsers/
│   ├── musicxml_parser.dart
│   ├── measure_handler.dart
│   └── part_handler.dart
│
├── game/
│   ├── game_session.dart
│   ├── score_engine.dart
│   ├── metronome_controller.dart
│   └── input_handler.dart
│
├── screens/
│   ├── game_screen.dart
│   ├── settings_screen.dart
│   ├── file_picker_screen.dart
│   └── results_screen.dart
│
└── main.dart
```

---

## 🚀 Próximas Etapas de Desarrollo

1. **Setup del Proyecto Flutter**
   - Crear proyecto con estructura modular
   - Configurar pubspec.yaml con dependencias

2. **Implementación del Musical Engine**
   - TicksEngine (base temporal con TPQN 480)
   - TimeSignature y conversiones
   - PickupCalculator

3. **Implementación del Visual Engine**
   - StaffRenderer (pentagrama)
   - NoteVisual (dibujo de notas con SMuFL)
   - AnimationManager

4. **MusicXML Parser**
   - Análisis de archivos XML
   - Conversión a modelo interno

5. **Game Logic**
   - GameSession
   - ScoreEngine
   - MetronomeController

6. **UI y Presentación**
   - GameScreen
   - Settings
   - File picker para MusicXML

---

## 📊 Comparativa: HTML vs Flutter

| Aspecto | Prototipo HTML | App Flutter |
|---------|----------------|-------------|
| Base Temporal | Milisegundos | TPQN 480 (estándar) |
| Audio | Web Audio API | flutter_sound / audioplayers |
| Visualización | Canvas HTML | CustomPaint + SMuFL |
| Entrada MusicXML | ❌ No soportado | ✅ Soportado (xml package) |
| Arquitectura | Monolítica | Modular (Lógica ≠ Visual) |
| Multiplataforma | Navegador | iOS/Android/Web/Desktop |

---

## 🎯 Ventajas de la Nueva Arquitectura

✅ **Separación de Responsabilidades**: Lógica musical completamente independiente de visualización
✅ **Estándar TPQN**: Compatible con MIDI, MusicXML y herramientas profesionales
✅ **SMuFL**: Rendering profesional de notación musical
✅ **MusicXML**: Soporte para archivos estándar de la industria
✅ **Testeable**: Lógica musical puede ser testeada sin UI
✅ **Escalable**: Fácil agregar nuevas métricas, tipos de ejercicio, etc.
✅ **Cross-platform**: Flutter ejecuta en múltiples plataformas

---

**Documento preparado para iniciar desarrollo de la app Flutter modular**
