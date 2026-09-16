# Análisis y arquitectura del proyecto actual

## Estado actual del proyecto

Este proyecto ya no es solo un prototipo conceptual ni una propuesta de arquitectura. La base funcional de la aplicación musical ya está implementada en Flutter y se organiza en capas bien definidas.

## Objetivo del sistema

La aplicación funciona como entrenador musical orientado a:

- cargar ejercicios desde archivos MusicXML
- evaluar precisión en tiempo y altura
- renderizar pentagramas y notas visualmente
- reproducir metrónomo y audio de piano
- gestionar flujo de juego, puntuación y feedback

## Arquitectura real implementada

### Capa 1: UI
La interfaz se encuentra en el directorio [lib/screens](lib/screens), con pantallas principales como:

- `HomeScreen`
- `ExerciseSelectionScreen`
- `GameScreen`
- `SettingsScreen`
- `ResultsScreen`

La aplicación principal se inicia en [lib/main.dart](lib/main.dart), donde se monta el árbol de widgets y se inicializa el provider de ejercicios.

### Capa 2: Providers / Estado global
El estado principal del flujo de ejercicios está gestionado por [lib/providers/exercise_provider.dart](lib/providers/exercise_provider.dart).

Responsabilidades actuales:

- cargar ejercicios desde assets
- exponer la lista de ejercicios disponibles
- indicar estado de carga y errores
- seleccionar un ejercicio activo
- devolver estadísticas calculadas

### Capa 3: Dominio musical (core)
El dominio musical está en [lib/core](lib/core), reagrupado en:

- modelos de nota, compás, armadura y ejercicio
- motor musical con lógica temporal y de puntuación
- utilidades de cálculo del gameplay

Archivos clave:

- [lib/core/models/note_model.dart](lib/core/models/note_model.dart)
- [lib/core/models/time_signature.dart](lib/core/models/time_signature.dart)
- [lib/core/models/key_signature.dart](lib/core/models/key_signature.dart)
- [lib/core/musical_engine/ticks_engine.dart](lib/core/musical_engine/ticks_engine.dart)
- [lib/core/musical_engine/pickup_calculator.dart](lib/core/musical_engine/pickup_calculator.dart)
- [lib/core/musical_engine/hit_window.dart](lib/core/musical_engine/hit_window.dart)

Estas clases representan el núcleo del sistema de ritmo y evaluación.

### Capa 4: Motor de juego
La lógica del juego se centraliza en [lib/game/game_session.dart](lib/game/game_session.dart).

`GameSession` es el orquestador del juego y gestiona:

- estado del juego (`idle`, `playing`, `paused`, `finished`)
- validación de hits por tiempo
- comparación de pitch
- combo y puntuación
- historial de feedback
- notificación a la UI de cambios relevantes

También se usa [lib/game/metronome_controller.dart](lib/game/metronome_controller.dart) para controlar el pulso del ejercicio.

### Capa 5: Parser MusicXML
El parseo del contenido musical se hace en [lib/parsers/musicxml_parser.dart](lib/parsers/musicxml_parser.dart).

Responsabilidades actuales:

- leer XML de MusicXML
- detectar compás, tonalidad y BPM
- convertir notas en objetos internos
- calcular duración en ticks
- soportar rest, alteraciones y tipos de nota

Esto permite que la resta del sistema trabaje con un modelo propio en lugar de depender directamente del formato externo.

### Capa 6: Visual Engine
El render gráfico se encuentra en [lib/visual_engine](lib/visual_engine).

Elementos principales:

- `SMuFLRenderer`
- `StaffRenderer`
- `NoteVisual`
- `AnimationManager`
- `NoteLayout`

Se encarga de dibujar:

- el pentagrama
- notas y silencios
- líneas de hit
- feedback visual por precisión
- animaciones de notas y aciertos

### Capa 7: Audio
En [lib/audio](lib/audio) se implementa la parte sonora:

- metrónomo
- generación de clicks
- servicio para notas de piano
- control del audio asociado a la sesión de juego

### Capa 8: Servicios y carga de datos
Los servicios se ubican en [lib/services](lib/services), sobre todo:

- `ExerciseLoaderService`: carga ejercicios desde `assets/exercises`
- `MusicXmlPreloadService`: apoyo para precarga de archivos XML

## Relación entre módulos

La relación actual del sistema es la siguiente:

```text
UI / Screens
    ↓
Providers
    ↓
GameSession / Core / Musical Logic
    ↓
MusicXMLParser
    ↓
Visual Engine + Audio
```

Es decir, la pantalla dispara acciones y observa cambios de estado; el `GameSession` resuelve la lógica; el parser convierte el contenido musical; y las capas visual y de audio se encargan de la representación y sonido.

## Principios arquitectónicos observados

La solución actual ya muestra una estructura bastante coherente:

- separación entre dominio y presentación
- desacople del formato externo (MusicXML) del resto del código
- independencia del motor visual respecto a la lógica del juego
- un punto de orquestación único: `GameSession`
- división clara entre audio, render y evaluación

## Fortalezas del proyecto actual

- el modelo de dominio está bien definido
- el flujo de ejercicios está integrado con assets y selección de pantalla
- la lógica de evaluación está centralizada
- el render del pentagrama y la animación están encapsulados
- la app ya tiene una base real y funcional sobre la que continuar desarrollando

## Puntos de mejora

Aunque la arquitectura es sólida, todavía hay margen para reforzarla:

1. unificar la gestión de estado en pantallas complejas
2. reducir lógica de UI mezclada con control del juego
3. formalizar interfaces para audio y servicios
4. definir mejor el contrato entre parser y dominio
5. aumentar consistencia en naming y responsabilidades entre módulos

## Conclusión

Este proyecto ya no está en una etapa de prototipo conceptual puro. Tiene una arquitectura funcional bastante madura para una app educativa musical con Flutter, con capas bien diferenciadas y una base sólida para continuar con nuevas mecánicas, modos de juego o integraciones multimedia.

La documentación de referencia actual debe entenderse como una descripción del proyecto real y no como un plano futuro idealizado.
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
