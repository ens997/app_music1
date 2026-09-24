# app_music1

Aplicación Flutter para entrenamiento musical y rítmico con ejercicios precargados en formato MusicXML, sistema de puntuación, metrónomo y visualización de pentagramas.

## Descripción general

Este proyecto implementa una app de práctica musical orientada a:

- cargar ejercicios desde assets y archivos MusicXML
- evaluar precisión rítmica y de altura
- renderizar pentagramas y notas con engine visual propio
- reproducir metrónomo y audio de piano
- ofrecer flujo de juego con pantallas de selección, partida y resultados

La aplicación está pensada como un entrenador musical interactivo, con lógica separada por capas y una base bastante clara para extender funcionalidades.

## Estado actual del proyecto

La implementación actual ya incluye:

- carga de ejercicios desde `assets/exercises`
- selección de nivel/dificultad
- pantalla principal y flujo de navegación
- parser MusicXML básico para notas, tiempos, compases y armaduras
- motor de juego con detección de hits por tiempo y pitch
- cálculo de puntuación, combo y estadísticas
- render visual del pentagrama con `CustomPainter`
- animaciones de feedback visual
- audio de metrónomo y servicio de piano
- reloj musical monotónico con fuente de tiempo inyectable para tests
- calibración persistente de latencia de audio y entrada (0-300 ms)
- pruebas unitarias para motor visual y lógica relevante

## Stack tecnológico

- Flutter
- Dart
- Provider para estado global
- MusicXML parsing con `xml`
- `CustomPainter` para render visual
- Asset pipeline para ejercicios

## Estructura del proyecto

```text
lib/
├── audio/
│   ├── game_audio_track_controller.dart
│   ├── metronome_click_generator.dart
│   └── piano_audio_service.dart
├── core/
│   ├── models/
│   ├── musical_engine/
│   ├── core.dart
│   └── globals.dart
├── game/
│   ├── game.dart
│   ├── game_session.dart
│   └── metronome_controller.dart
├── parsers/
│   └── musicxml_parser.dart
├── providers/
│   └── exercise_provider.dart
├── screens/
│   ├── exercise_selection_screen.dart
│   ├── game_screen.dart
│   ├── level_select_screen.dart
│   ├── results_screen.dart
│   ├── settings_screen.dart
│   └── screens.dart
├── services/
│   ├── exercise_loader_service.dart
│   ├── latency_settings_service.dart
│   └── musicxml_preload_service.dart
├── visual_engine/
│   ├── animation_manager.dart
│   ├── bravura_glyphs.dart
│   ├── note_layout.dart
│   ├── note_visual.dart
│   ├── smufl_renderer.dart
│   ├── staff_renderer.dart
│   ├── visual_engine.dart
│   └── widgets/
├── main.dart
└──
```

## Arquitectura actual

La aplicación sigue una estructura por capas bastante clara:

### 1. UI / Screens
Responsable de la navegación y de mostrar la experiencia visual del usuario.

### 2. Providers
Gestiona el estado global de la aplicación, especialmente los ejercicios disponibles y la selección del usuario.

### 3. Core / Dominio musical
Contiene los modelos y motores del sistema musical:

- `NoteModel`
- `TimeSignature`
- `KeySignature`
- `TicksEngine`
- `PickupCalculator`
- `HitWindow`
- `ScoreEngine`

Estos módulos representan la lógica musical y evaluativa del juego.

### 4. Game Session
La clase `GameSession` orquesta la partida:

- estado de juego
- control de combo
- puntuación
- historial de hits
- detección de aciertos por tiempo y pitch
- notificaciones a la interfaz

El tiempo de la sesión se obtiene de `TicksEngine`, que usa `Stopwatch` como
reloj monotónico por defecto y permite inyectar `FakeTimeSource` en pruebas.
El `Ticker` de Flutter solo actualiza la interfaz y el desplazamiento visual;
no es la fuente de verdad temporal.

### 5. Parsers
`MusicXMLParser` convierte archivos MusicXML a modelos internos del proyecto para su uso dentro de la lógica del juego.

### 6. Visual Engine
El motor visual dibuja pentagramas, notas, líneas de hit y animaciones mediante `CustomPainter` y SMuFL-related rendering.

### 7. Audio
La capa de audio gestiona metrónomo y notas de piano para la experiencia de práctica musical.

## Flujo principal de ejecución

1. La app carga ejercicios desde `assets/exercises`.
2. El usuario elige un ejercicio desde la UI.
3. El contenido MusicXML se interpreta con `MusicXMLParser`.
4. Se crea una instancia de `GameSession` con el score cargado.
5. El juego compara la entrada del usuario frente a las notas esperadas.
6. La UI actualiza score, feedback y visualización.

## Ejecución local

Requisitos:

- Flutter SDK instalado
- dispositivo emulado o físico configurado

Comandos:

```bash
flutter pub get
flutter run
```

## Testing

El proyecto incluye pruebas para:

- motor visual
- render de staff y notas
- animaciones
- lógica de puntuación y feedback
- reloj temporal y compensación de latencia

Ejemplo:

```bash
flutter test
```

## Observaciones de diseño

El proyecto ya tiene una base sólida para continuar con una aplicación musical interactiva. La arquitectura actual está bastante bien separada por capas, aunque todavía hay margen para:

- unificar más estrictamente el manejo de estado de pantalla
- reducir acoplamiento en pantallas complejas
- documentar contratos entre módulos
- refinar patrones de acceso a servicios y audio

La pantalla de configuración permite ajustar la latencia percibida del audio y
la latencia de entrada. Estos valores se guardan con `shared_preferences` y se
aplican a las nuevas sesiones de juego.

## Ficheros de documentación relacionados

- `ANALISIS_Y_ARQUITECTURA.md`
- `PROYECTO_FLUTTER_BASE.md`
- `GUIA_IMPLEMENTACION_FLUTTER.md`
- `PRUEBAS_LISTAS.md`

## Estado sugerido

Proyecto en desarrollo activo con base funcional de entrenamiento musical, motor visual y lógica de juego ya implementados.
