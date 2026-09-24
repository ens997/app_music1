import 'dart:math' as math;

/// Conversión y normalización de nombres de notas musicales.
class PitchUtils {
  static final RegExp _pitchRegex = RegExp(r'^([A-G])([#b]{0,2})(-?\d+)$');

  static const Map<String, int> _semitones = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  static const List<String> _sharpNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static ({String note, String accidental, int octave})? parse(String pitch) {
    final symbolsNormalized = pitch
        .trim()
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b');
    if (symbolsNormalized.isEmpty) return null;
    final normalized =
        '${symbolsNormalized[0].toUpperCase()}${symbolsNormalized.substring(1).toLowerCase()}';
    final match = _pitchRegex.firstMatch(normalized);
    if (match == null) return null;

    return (
      note: match.group(1)!,
      accidental: match.group(2) ?? '',
      octave: int.parse(match.group(3)!),
    );
  }

  static int? toMidi(String pitch) {
    final parsed = parse(pitch);
    if (parsed == null) return null;

    var semitone = _semitones[parsed.note]!;
    for (final symbol in parsed.accidental.split('')) {
      semitone += symbol == '#' ? 1 : -1;
    }
    return (parsed.octave + 1) * 12 + semitone;
  }

  static String fromMidi(int midi) {
    final pitchClass = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${_sharpNames[pitchClass]}$octave';
  }

  static String normalize(String pitch) {
    final midi = toMidi(pitch);
    return midi == null ? pitch.trim().toUpperCase() : fromMidi(midi);
  }

  static double? toFrequency(String pitch) {
    final midi = toMidi(pitch);
    if (midi == null) return null;
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0).toDouble();
  }
}
