import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';

void main() {
  group('PitchUtils', () {
    test('converts enharmonic and double accidental pitches to MIDI', () {
      expect(PitchUtils.toMidi('C4'), 60);
      expect(PitchUtils.toMidi('C#4'), 61);
      expect(PitchUtils.toMidi('Db4'), 61);
      expect(PitchUtils.toMidi('C##4'), 62);
      expect(PitchUtils.toMidi('Cbb4'), 58);
      expect(PitchUtils.toMidi('B#3'), 60);
      expect(PitchUtils.toMidi('Cb4'), 59);
      expect(PitchUtils.toMidi('invalid'), isNull);
    });

    test('normalizes pitches to canonical sharp names', () {
      expect(PitchUtils.normalize('Db4'), 'C#4');
      expect(PitchUtils.normalize('C##4'), 'D4');
      expect(PitchUtils.normalize('Cbb4'), 'A#3');
    });
  });

  group('NoteModel pitch calculation', () {
    test('uses pitch alteration or the legacy accidental fallback once', () {
      expect(
        NoteModel(
          pitch: 'C#4',
          duration: NoteDuration.quarter,
          absoluteTick: 0,
        ).getMidiNumber(),
        61,
      );
      expect(
        NoteModel(
          pitch: 'C4',
          accidental: Accidental.sharp,
          duration: NoteDuration.quarter,
          absoluteTick: 0,
        ).getMidiNumber(),
        61,
      );
      expect(
        NoteModel(
          pitch: 'Cbb4',
          duration: NoteDuration.quarter,
          absoluteTick: 0,
        ).getMidiNumber(),
        58,
      );
    });
  });
}
