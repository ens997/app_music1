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
        throw FormatException('Formato MusicXML no reconocido (falta <score-partwise>)');
      }

      final work = score.getElement('work');
      final title = work?.getElement('work-title')?.text.trim() ?? 'Untitled';

      final identification = score.getElement('identification');
      final composer = identification
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
            final beats = int.tryParse(time.getElement('beats')?.text ?? '') ?? 4;
            final beatType = int.tryParse(time.getElement('beat-type')?.text ?? '') ?? 4;
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
          Accidental accidental = Accidental.natural;
          bool displayAccidental = false;
          int dotCount = 0;

          if (!isRest) {
            final pitch = note.getElement('pitch');
            if (pitch != null) {
              pitchName = pitch.getElement('step')?.text.trim() ?? 'C';
              octave = int.tryParse(pitch.getElement('octave')?.text ?? '') ?? 4;

              final alterText = pitch.getElement('alter')?.text;
              if (alterText != null) {
                final alter = int.tryParse(alterText) ?? 0;
                if (alter == 1) {
                  accidental = Accidental.sharp;
                } else if (alter == -1) {
                  accidental = Accidental.flat;
                } else if (alter == 2) {
                  accidental = Accidental.doubleSharp;
                } else if (alter == -2) {
                  accidental = Accidental.doubleFlat;
                }
              }
            }

            final accidentalText = note.getElement('accidental')?.text.trim().toLowerCase();
            if (accidentalText != null && accidentalText.isNotEmpty) {
              displayAccidental = true;
              switch (accidentalText) {
                case 'sharp':
                  accidental = Accidental.sharp;
                  break;
                case 'flat':
                  accidental = Accidental.flat;
                  break;
                case 'double-sharp':
                case 'sharp-sharp':
                  accidental = Accidental.doubleSharp;
                  break;
                case 'double-flat':
                  accidental = Accidental.doubleFlat;
                  break;
                case 'natural':
                default:
                  accidental = Accidental.natural;
                  break;
              }
            }
          }

          // Duración en divisions
          final durationText = note.getElement('duration')?.text;
          final durationDivisions = int.tryParse(durationText ?? '') ?? 0;
          dotCount = note.findElements('dot').length;

          final typeText = note.getElement('type')?.text.trim().toLowerCase();
          final durationEnum = _durationFromType(typeText, durationDivisions, divisions);

          // Leer informaci?n de barras (beams) por nivel.
          BeamType beamType = BeamType.none;
          final beamLevels = <int, BeamType>{};
          final beamElements = note.findElements('beam');
          if (beamElements.isNotEmpty) {
            for (final beamElement in beamElements) {
              final beamNumber =
                  int.tryParse(beamElement.getAttribute('number') ?? '1') ?? 1;
              final parsedBeamType =
                  _beamTypeFromText(beamElement.text.trim().toLowerCase());
              if (parsedBeamType != BeamType.none) {
                beamLevels[beamNumber] = parsedBeamType;
              }
            }
            beamType = beamLevels[1] ?? BeamType.none;
          }

          // Calcular ticks en TPQN=480
          final ticksPerDivision = (TicksEngine.TPQN / divisions);
          final durationTicks = (durationDivisions * ticksPerDivision).round();

          // Nombre pitch completo
          final pitchFull = '$pitchName$octave';

          final noteModel = NoteModel(
            pitch: pitchFull,
            duration: durationEnum,
            durationTicksOverride: durationTicks,
            isDotted: dotCount > 0,
            absoluteTick: absoluteTick,
            accidental: accidental,
            displayAccidental: displayAccidental,
            isRest: isRest,
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

  static BeamType _beamTypeFromText(String beamText) {
    switch (beamText) {
      case 'begin':
        return BeamType.begin;
      case 'continue':
        return BeamType.continuation;
      case 'end':
        return BeamType.end;
      default:
        return BeamType.none;
    }
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
        final ticksPerDivision = (TicksEngine.TPQN / divisions);
        final ticks = durationDivisions * ticksPerDivision;
        if (ticks >= NoteDuration.whole.getTicksAtTPQN480()) return NoteDuration.whole;
        if (ticks >= NoteDuration.half.getTicksAtTPQN480()) return NoteDuration.half;
        if (ticks >= NoteDuration.quarter.getTicksAtTPQN480()) return NoteDuration.quarter;
        if (ticks >= NoteDuration.eighth.getTicksAtTPQN480()) return NoteDuration.eighth;
        return NoteDuration.sixteenth;
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
