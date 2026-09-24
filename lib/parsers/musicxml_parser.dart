import 'dart:io';

import 'package:xml/xml.dart';

import '../core/core.dart';

/// Parser para archivos MusicXML
/// Convierte notación XML a modelo interno de la aplicación
class MusicXMLParser {
  /// Parsea contenido XML de MusicXML (formato ScorePartwise)
  static MusicScore parse(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final score = document.getElement('score-partwise');

      if (score == null) {
        throw FormatException(
          'Formato MusicXML no reconocido (falta <score-partwise>)',
        );
      }

      final work = score.getElement('work');
      final title = work?.getElement('work-title')?.text.trim() ?? 'Untitled';

      final identification = score.getElement('identification');
      final composer =
          identification
              ?.findElements('creator')
              .firstWhere(
                (node) => node.getAttribute('type') == 'composer',
                orElse: () => XmlElement(XmlName('creator')),
              )
              .text
              .trim() ??
          'Unknown';

      // Default values
      int divisions = 1;
      TimeSignature timeSignature = TimeSignature(4, 4);
      KeySignature keySignature = KeySignature(fifths: 0);
      int bpm = 120;

      final notes = <NoteModel>[];
      int absoluteTick = 0;

      // Solo procesamos la primera parte para un parser básico
      final part = score.getElement('part');
      if (part == null) {
        throw FormatException('No se encontró <part> en el MusicXML');
      }

      for (final measure in part.findElements('measure')) {
        // Actualizar atributos cuando existan
        final attributes = measure.getElement('attributes');
        if (attributes != null) {
          final divisionsText = attributes.getElement('divisions')?.text;
          if (divisionsText != null) {
            divisions = int.tryParse(divisionsText) ?? divisions;
          }

          final time = attributes.getElement('time');
          if (time != null) {
            final beats =
                int.tryParse(time.getElement('beats')?.text ?? '') ?? 4;
            final beatType =
                int.tryParse(time.getElement('beat-type')?.text ?? '') ?? 4;
            timeSignature = TimeSignature(beats, beatType);
          }

          final key = attributes.getElement('key');
          if (key != null) {
            final fifthsText = key.getElement('fifths')?.text;
            final fifths = int.tryParse(fifthsText ?? '0') ?? 0;
            final mode = key.getElement('mode')?.text ?? 'major';
            keySignature = KeySignature(fifths: fifths, mode: mode);
          }

          // Se puede leer clave (clef) si es necesario
        }

        // Tempo / metronome
        for (final direction in measure.findElements('direction')) {
          final sound = direction.getElement('sound');
          if (sound != null) {
            final tempoValue = sound.getAttribute('tempo');
            if (tempoValue != null) {
              bpm = int.tryParse(tempoValue) ?? bpm;
            }
          }
        }

        // Notas dentro del compás
        for (final note in measure.findElements('note')) {
          // Si es silencio, se agrega como nota tipo rest
          final isRest = note.getElement('rest') != null;

          String pitchName = 'C';
          int octave = 4;
          int pitchAlter = 0;
          Accidental accidental = Accidental.natural;
          bool displayAccidental = false;

          if (!isRest) {
            final pitch = note.getElement('pitch');
            if (pitch != null) {
              pitchName = pitch.getElement('step')?.text.trim() ?? 'C';
              octave =
                  int.tryParse(pitch.getElement('octave')?.text ?? '') ?? 4;

              final alterText = pitch.getElement('alter')?.text;
              if (alterText != null) {
                displayAccidental = true;
                pitchAlter = int.tryParse(alterText) ?? 0;
                if (pitchAlter == 1) {
                  accidental = Accidental.sharp;
                } else if (pitchAlter == -1) {
                  accidental = Accidental.flat;
                } else if (pitchAlter == 2) {
                  accidental = Accidental.doubleSharp;
                } else if (pitchAlter == -2) {
                  accidental = Accidental.doubleFlat;
                }
              }
            }

            final accidentalText = note
                .getElement('accidental')
                ?.text
                .trim()
                .toLowerCase();
            if (accidentalText != null && accidentalText.isNotEmpty) {
              displayAccidental = true;
              accidental = _accidentalFromMusicXml(accidentalText);
            }
          }

          // Duración en divisions
          final durationText = note.getElement('duration')?.text;
          final durationDivisions = int.tryParse(durationText ?? '') ?? 0;

          final typeText = note.getElement('type')?.text.trim().toLowerCase();
          final durationEnum = _durationFromType(
            typeText,
            durationDivisions,
            divisions,
          );
          final isDotted = note.getElement('dot') != null;

          // Leer todos los niveles de barras. MusicXML usa number="1" para
          // la barra principal y number="2" para la barra de semicorcheas.
          BeamType beamType = BeamType.none;
          final beamLevels = <int, BeamType>{};
          for (final beamElement in note.findElements('beam')) {
            final level =
                int.tryParse(beamElement.getAttribute('number') ?? '1') ?? 1;
            final beamText = beamElement.text.trim().toLowerCase();
            final parsedBeamType = switch (beamText) {
              'begin' => BeamType.begin,
              'continue' => BeamType.continuation,
              'end' => BeamType.end,
              'forward hook' => BeamType.forwardHook,
              'backward hook' => BeamType.backwardHook,
              _ => BeamType.none,
            };

            beamLevels[level] = parsedBeamType;
            if (level == 1) beamType = parsedBeamType;
          }

          // Calcular ticks en TPQN=480
          final ticksPerDivision = (TicksEngine.tpnq / divisions);
          final durationTicks = (durationDivisions * ticksPerDivision).round();

          // El pitch conserva el alter semántico; accidental queda disponible
          // para decidir cómo se dibuja la notación.
          final pitchFull = pitchAlter == 0
              ? '$pitchName$octave'
              : '$pitchName${pitchAlter > 0 ? '#' * pitchAlter : 'b' * -pitchAlter}$octave';

          final noteModel = NoteModel(
            pitch: pitchFull,
            duration: durationEnum,
            durationTicksOverride: durationTicks,
            absoluteTick: absoluteTick,
            accidental: accidental,
            isRest: isRest,
            isDotted: isDotted,
            displayAccidental: displayAccidental,
            velocity: 64,
            beamType: beamType,
            beamLevels: beamLevels,
          );

          notes.add(noteModel);

          // Valores para siguiente nota
          absoluteTick += durationTicks;
        }
      }

      return MusicScore(
        title: title,
        composer: composer,
        timeSignature: timeSignature,
        keySignature: keySignature,
        divisions: divisions,
        notes: notes,
        bpm: bpm,
      );
    } catch (e) {
      throw Exception('Error al parsear MusicXML: $e');
    }
  }

  /// Parsea desde un archivo
  static Future<MusicScore> parseFile(String filePath) async {
    final file = File(filePath);
    final xmlContent = await file.readAsString();
    return parse(xmlContent);
  }

  static NoteDuration _durationFromType(
    String? type,
    int durationDivisions,
    int divisions,
  ) {
    // Preferimos usar el tipo si está presente
    switch (type) {
      case 'whole':
        return NoteDuration.whole;
      case 'half':
        return NoteDuration.half;
      case 'quarter':
        return NoteDuration.quarter;
      case 'eighth':
        return NoteDuration.eighth;
      case '16th':
      case 'sixteenth':
        return NoteDuration.sixteenth;
      default:
        // Fallback por duración relativa usando divisiones
        final ticksPerDivision = (TicksEngine.tpnq / divisions);
        final ticks = durationDivisions * ticksPerDivision;
        if (ticks >= NoteDuration.whole.getTicksAtTPQN480())
          return NoteDuration.whole;
        if (ticks >= NoteDuration.half.getTicksAtTPQN480())
          return NoteDuration.half;
        if (ticks >= NoteDuration.quarter.getTicksAtTPQN480())
          return NoteDuration.quarter;
        if (ticks >= NoteDuration.eighth.getTicksAtTPQN480())
          return NoteDuration.eighth;
        return NoteDuration.sixteenth;
    }
  }

  static Accidental _accidentalFromMusicXml(String value) {
    switch (value) {
      case 'sharp':
        return Accidental.sharp;
      case 'flat':
        return Accidental.flat;
      case 'double-sharp':
      case 'sharp-sharp':
        return Accidental.doubleSharp;
      case 'double-flat':
        return Accidental.doubleFlat;
      case 'natural':
      default:
        return Accidental.natural;
    }
  }
}

/// Modelo de partitura musical
class MusicScore {
  final String title;
  final String composer;
  final TimeSignature timeSignature;
  final KeySignature keySignature;
  final int divisions; // Divisiones por quarter note en el XML
  final List<NoteModel> notes;
  final int bpm;

  MusicScore({
    required this.title,
    required this.composer,
    required this.timeSignature,
    this.keySignature = const KeySignature(fifths: 0),
    required this.divisions,
    required this.notes,
    this.bpm = 120,
  });

  /// Retorna la duración total en ticks
  int getTotalTicks() {
    if (notes.isEmpty) return 0;
    final lastNote = notes.last;
    return lastNote.absoluteTick + lastNote.durationTicks;
  }

  @override
  String toString() {
    return 'MusicScore($title by $composer, ${notes.length} notas, $timeSignature)';
  }
}

/// Manejador de partes musicales
class PartHandler {
  // TODO: Procesar múltiples partes/instrumentos
  // TODO: Manejar voces
  // TODO: Sincronizar timing entre partes
}

/// Manejador de compases
class MeasureHandler {
  // TODO: Procesar atributos del compás
  // TODO: Procesar notas dentro del compás
  // TODO: Calcular timing absoluto
}

MusicScore parseMusicXmlInBackground(String xmlContent) {
  return MusicXMLParser.parse(xmlContent);
}
