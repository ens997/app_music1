/// Enumeraciones base para la aplicación de entrenamiento musical

/// Tipos de duraciones de notas musicales
/// Basadas en TPQN (Ticks Per Quarter Note) = 480
enum NoteDuration {
  whole,      // 4 beats = 1920 ticks
  half,       // 2 beats = 960 ticks
  quarter,    // 1 beat = 480 ticks
  eighth,     // 0.5 beat = 240 ticks
  sixteenth;  // 0.25 beat = 120 ticks

  /// Retorna la duración en ticks (TPQN 480)
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

  /// Nombre legible de la duración
  String get displayName {
    switch (this) {
      case NoteDuration.whole:
        return 'Redonda';
      case NoteDuration.half:
        return 'Blanca';
      case NoteDuration.quarter:
        return 'Negra';
      case NoteDuration.eighth:
        return 'Corchea';
      case NoteDuration.sixteenth:
        return 'Semicorchea';
    }
  }
}

/// Nombres de notas musicales
enum NoteName {
  C,
  D,
  E,
  F,
  G,
  A,
  B;

  /// Número MIDI base (sin octava)
  int get midiNumber {
    switch (this) {
      case NoteName.C:
        return 0;
      case NoteName.D:
        return 2;
      case NoteName.E:
        return 4;
      case NoteName.F:
        return 5;
      case NoteName.G:
        return 7;
      case NoteName.A:
        return 9;
      case NoteName.B:
        return 11;
    }
  }

  /// Símbolo de la nota
  String get symbol {
    return name;
  }
}

/// Alteraciones (accidentes)
enum Accidental {
  natural,       // ♮
  sharp,         // ♯ (sostenido)
  flat,          // ♭ (bemol)
  doubleSharp,   // 𝄪
  doubleFlat;    // 𝄫

  /// Representación de la alteración
  String get symbol {
    switch (this) {
      case Accidental.natural:
        return '♮';
      case Accidental.sharp:
        return '♯';
      case Accidental.flat:
        return '♭';
      case Accidental.doubleSharp:
        return '𝄪';
      case Accidental.doubleFlat:
        return '𝄫';
    }
  }

  /// Cambio en semitones
  int get semitoneDelta {
    switch (this) {
      case Accidental.natural:
        return 0;
      case Accidental.sharp:
        return 1;
      case Accidental.flat:
        return -1;
      case Accidental.doubleSharp:
        return 2;
      case Accidental.doubleFlat:
        return -2;
    }
  }
}

/// Calidad del hit (precisión)
enum HitQuality {
  perfect,  // ±50ms
  great,    // ±100ms
  good,     // ±150ms
  miss;     // >150ms

  /// Puntos otorgados por esta calidad
  int getScore() {
    switch (this) {
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

  /// Descripción legible
  String get displayName {
    switch (this) {
      case HitQuality.perfect:
        return '¡PERFECTO!';
      case HitQuality.great:
        return 'Excelente';
      case HitQuality.good:
        return 'Bueno';
      case HitQuality.miss:
        return 'Pérdido';
    }
  }

  /// Color para feedback visual (en formato ARGB)
  int get colorValue {
    switch (this) {
      case HitQuality.perfect:
        return 0xFF4ecca3; // Verde
      case HitQuality.great:
        return 0xFF4287f5; // Azul
      case HitQuality.good:
        return 0xFFffc107; // Amarillo
      case HitQuality.miss:
        return 0xFFe94560; // Rojo
    }
  }
}

/// Tipo de clave musical
enum ClefType {
  treble,  // Clave de Sol (G)
  bass,    // Clave de Fa (F)
  alto;    // Clave de Do (C)

  /// Símbolo Unicode de la clave
  String get unicodeSymbol {
    switch (this) {
      case ClefType.treble:
        return '𝄞'; // U+1D11E
      case ClefType.bass:
        return '𝄢'; // U+1D122
      case ClefType.alto:
        return '𝄡'; // U+1D121
    }
  }

  /// Nombre legible
  String get displayName {
    switch (this) {
      case ClefType.treble:
        return 'Clave de Sol';
      case ClefType.bass:
        return 'Clave de Fa';
      case ClefType.alto:
        return 'Clave de Do';
    }
  }
}

/// Estados del juego
enum GameState {
  idle,        // Esperando instrucciones
  playing,     // Jugando
  paused,      // En pausa
  finished;    // Completado

  String get displayName {
    switch (this) {
      case GameState.idle:
        return 'Inactivo';
      case GameState.playing:
        return 'Jugando';
      case GameState.paused:
        return 'En pausa';
      case GameState.finished:
        return 'Completado';
    }
  }
}

/// Tipo de ejercicio
enum ExerciseType {
  rhythmTraining,     // Entrenamiento rítmico
  pitchRecognition,   // Reconocimiento de altura
  sightReading,       // Lectura a primera vista
  earTraining;        // Entrenamiento auditivo

  String get displayName {
    switch (this) {
      case ExerciseType.rhythmTraining:
        return 'Entrenamiento Rítmico';
      case ExerciseType.pitchRecognition:
        return 'Reconocimiento de Altura';
      case ExerciseType.sightReading:
        return 'Lectura a Primera Vista';
      case ExerciseType.earTraining:
        return 'Entrenamiento Auditivo';
    }
  }
}

/// Dificultad del ejercicio
enum Difficulty {
  beginner,
  intermediate,
  advanced,
  expert;

  String get displayName {
    switch (this) {
      case Difficulty.beginner:
        return 'Principiante';
      case Difficulty.intermediate:
        return 'Intermedio';
      case Difficulty.advanced:
        return 'Avanzado';
      case Difficulty.expert:
        return 'Experto';
    }
  }

  /// BPM recomendado para esta dificultad
  int get recommendedBPM {
    switch (this) {
      case Difficulty.beginner:
        return 60;
      case Difficulty.intermediate:
        return 90;
      case Difficulty.advanced:
        return 120;
      case Difficulty.expert:
        return 150;
    }
  }
}

/// Tipo de barra de agrupación (beam) para notas
enum BeamType {
  none,     // Sin barra
  begin,    // Inicio de barra
  continuation, // Continuación de barra
  end;      // Fin de barra

  /// Es parte de una barra
  bool get isBeamed => this != BeamType.none;
}
