import 'package:flutter_test/flutter_test.dart';
import 'package:app_music1/core/core.dart';

void main() {
  group('TicksEngine Tests', () {
    test('TicksEngine should initialize with default BPM 120', () {
      final engine = TicksEngine();
      expect(engine.bpm, 120);
      expect(engine.currentTick, 0);
      expect(engine.isRunning, false);
    });

    test('TicksEngine should convert quarters correctly', () {
      final engine = TicksEngine(initialBpm: 120);
      final quarterDuration = engine.getQuarterNoteDuration();
      expect(quarterDuration, 500); // 60000 / 120 = 500ms
    });

    test('TicksEngine should validate BPM range', () {
      final engine = TicksEngine();
      expect(() => engine.setBpm(20), throwsArgumentError);
      expect(() => engine.setBpm(400), throwsArgumentError);
      expect(() => engine.setBpm(100), returnsNormally);
    });

    test('TicksEngine should convert ticks to milliseconds', () {
      final engine = TicksEngine(initialBpm: 120);
      final ms = engine.ticksToMilliseconds(480); // 1 quarter note
      expect(ms, closeTo(500.0, 1.0)); // ~500ms
    });

    test('TicksEngine should convert milliseconds to ticks', () {
      final engine = TicksEngine(initialBpm: 120);
      final ticks = engine.millisecondsToTicks(500.0);
      expect(ticks, 480); // 1 quarter note = 480 ticks
    });
  });

  group('TimeSignature Tests', () {
    test('4/4 should have 1920 ticks per measure', () {
      final timeSig = TimeSignature(4, 4);
      expect(timeSig.getTicksPerMeasure(), 1920);
    });

    test('3/4 should have 1440 ticks per measure', () {
      final timeSig = TimeSignature(3, 4);
      expect(timeSig.getTicksPerMeasure(), 1440);
    });

    test('2/4 should have 960 ticks per measure', () {
      final timeSig = TimeSignature(2, 4);
      expect(timeSig.getTicksPerMeasure(), 960);
    });

    test('4/4 with 8 beat travel needs no pickup', () {
      final timeSig = TimeSignature(4, 4);
      final travelTicks = 8 * 480; // 8 beats = 3840 ticks
      expect(timeSig.needsPickup(travelTicks), false);
    });

    test('3/4 with 8 beat travel needs pickup', () {
      final timeSig = TimeSignature(3, 4);
      final travelTicks = 8 * 480; // 8 beats = 3840 ticks
      expect(timeSig.needsPickup(travelTicks), true);
    });
  });

  group('PickupCalculator Tests', () {
    test('4/4 with 8 beats travel should need 0 pickup', () {
      final timeSig = TimeSignature(4, 4);
      final travelTicks = 8 * 480;
      final pickup = PickupCalculator.calculatePickupTicks(travelTicks, timeSig);
      expect(pickup, 0);
    });

    test('3/4 with 8 beats travel should need 1.5 beats pickup', () {
      final timeSig = TimeSignature(3, 4);
      final travelTicks = 8 * 480; // 3840 ticks
      final pickup = PickupCalculator.calculatePickupTicks(travelTicks, timeSig);
      expect(pickup, 720); // 1.5 beats = 720 ticks
    });

    test('2/4 with 8 beats travel should need 0 pickup', () {
      final timeSig = TimeSignature(2, 4);
      final travelTicks = 8 * 480;
      final pickup = PickupCalculator.calculatePickupTicks(travelTicks, timeSig);
      expect(pickup, 0);
    });
  });

  group('NoteModel Tests', () {
    test('NoteModel should extract pitch correctly', () {
      final note = NoteModel(
        pitch: 'C4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
      );
      expect(note.noteName, 'C');
      expect(note.octave, 4);
    });

    test('NoteModel should calculate MIDI number correctly', () {
      final noteC4 = NoteModel(
        pitch: 'C4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
      );
      expect(noteC4.getMidiNumber(), 60); // Middle C in MIDI

      final noteA4 = NoteModel(
        pitch: 'A4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
      );
      expect(noteA4.getMidiNumber(), 69); // A4 = 440 Hz
    });

    test('NoteModel should calculate frequency correctly', () {
      final noteA4 = NoteModel(
        pitch: 'A4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
      );
      expect(noteA4.getFrequency(), closeTo(440.0, 0.1));
    });

    test('NoteModel duration ticks should be correct', () {
      final wholeNote = NoteModel(
        pitch: 'C4',
        duration: NoteDuration.whole,
        absoluteTick: 0,
      );
      expect(wholeNote.durationTicks, 1920);

      final quarterNote = NoteModel(
        pitch: 'C4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
      );
      expect(quarterNote.durationTicks, 480);
    });
  });

  group('HitWindow Tests', () {
    test('HitWindow should categorize perfect hits', () {
      final engine = TicksEngine(initialBpm: 120);
      final window = HitWindow(engine);
      final quality = window.getQuality(10); // 10 ticks deviation
      expect(quality, HitQuality.perfect);
    });

    test('HitWindow should categorize great hits', () {
      final engine = TicksEngine(initialBpm: 120);
      final window = HitWindow(engine);
      final quality = window.getQuality(60); // 60 ticks deviation
      expect(quality, HitQuality.great);
    });

    test('HitWindow should categorize good hits', () {
      final engine = TicksEngine(initialBpm: 120);
      final window = HitWindow(engine);
      final quality = window.getQuality(120); // 120 ticks deviation
      expect(quality, HitQuality.good);
    });

    test('HitWindow should categorize misses', () {
      final engine = TicksEngine(initialBpm: 120);
      final window = HitWindow(engine);
      final quality = window.getQuality(200); // 200 ticks deviation
      expect(quality, HitQuality.miss);
    });
  });

  group('ScoreEngine Tests', () {
    test('ScoreEngine should track hits correctly', () {
      final scoreEngine = ScoreEngine();
      scoreEngine.recordHit(HitQuality.perfect);
      scoreEngine.recordHit(HitQuality.great);
      expect(scoreEngine.hitCount, 2);
      expect(scoreEngine.totalScore, 500); // 300 + 200
    });

    test('ScoreEngine should track misses and reset combo', () {
      final scoreEngine = ScoreEngine();
      scoreEngine.recordHit(HitQuality.perfect);
      scoreEngine.recordHit(HitQuality.perfect);
      expect(scoreEngine.combo, 2);
      scoreEngine.recordMiss();
      expect(scoreEngine.combo, 0);
      expect(scoreEngine.missCount, 1);
    });

    test('ScoreEngine should calculate accuracy correctly', () {
      final scoreEngine = ScoreEngine();
      scoreEngine.recordHit(HitQuality.perfect);
      scoreEngine.recordHit(HitQuality.perfect);
      scoreEngine.recordMiss();
      final accuracy = scoreEngine.getAccuracy();
      expect(accuracy, closeTo(66.67, 0.1)); // 2/3
    });
  });

  group('Enumerations Tests', () {
    test('NoteDuration should return correct ticks', () {
      expect(NoteDuration.whole.getTicksAtTPQN480(), 1920);
      expect(NoteDuration.half.getTicksAtTPQN480(), 960);
      expect(NoteDuration.quarter.getTicksAtTPQN480(), 480);
      expect(NoteDuration.eighth.getTicksAtTPQN480(), 240);
      expect(NoteDuration.sixteenth.getTicksAtTPQN480(), 120);
    });

    test('HitQuality should return correct scores', () {
      expect(HitQuality.perfect.getScore(), 300);
      expect(HitQuality.great.getScore(), 200);
      expect(HitQuality.good.getScore(), 100);
      expect(HitQuality.miss.getScore(), 0);
    });

    test('Accidental should return correct semitone deltas', () {
      expect(Accidental.sharp.semitoneDelta, 1);
      expect(Accidental.flat.semitoneDelta, -1);
      expect(Accidental.natural.semitoneDelta, 0);
      expect(Accidental.doubleSharp.semitoneDelta, 2);
      expect(Accidental.doubleFlat.semitoneDelta, -2);
    });
  });
}
