import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/game/game.dart';
import 'package:app_music1/parsers/parsers.dart';

MusicScore _score(List<NoteModel> notes) {
  return MusicScore(
    title: 'Test',
    composer: 'Test',
    timeSignature: TimeSignature(4, 4),
    divisions: 1,
    notes: notes,
  );
}

GameSession _sessionWithNotes(List<String> pitches) {
  return GameSession(
    ticksEngine: TicksEngine(),
    scoreEngine: ScoreEngine(),
    musicScore: _score([
      for (final pitch in pitches)
        NoteModel(
          pitch: pitch,
          duration: NoteDuration.quarter,
          absoluteTick: 0,
        ),
    ]),
  );
}

void main() {
  test('GameSession ignores rests as input targets', () {
    final session = GameSession(
      ticksEngine: TicksEngine(),
      scoreEngine: ScoreEngine(),
      musicScore: _score([
        NoteModel(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          absoluteTick: 0,
          isRest: true,
        ),
        NoteModel(pitch: 'D4', duration: NoteDuration.quarter, absoluteTick: 0),
      ]),
    );

    session.start();

    expect(session.handleNoteInput('D4'), isTrue);
  });

  test('completion tick is based on the last playable note', () {
    final session = GameSession(
      ticksEngine: TicksEngine(),
      scoreEngine: ScoreEngine(),
      musicScore: _score([
        NoteModel(pitch: 'C4', duration: NoteDuration.quarter, absoluteTick: 0),
        NoteModel(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          absoluteTick: 480,
          isRest: true,
        ),
      ]),
    );

    expect(session.hasPlayableNotes, isTrue);
    expect(session.completionTick, 144);
  });

  test('empty scores do not throw and have no playable notes', () {
    final session = GameSession(
      ticksEngine: TicksEngine(),
      scoreEngine: ScoreEngine(),
      musicScore: _score([]),
    );

    expect(session.hasPlayableNotes, isFalse);
    expect(session.completionTick, 0);
  });

  test('GameSession matches enharmonic pitches', () {
    final session = GameSession(
      ticksEngine: TicksEngine(),
      scoreEngine: ScoreEngine(),
      musicScore: _score([
        NoteModel(
          pitch: 'C#4',
          duration: NoteDuration.quarter,
          absoluteTick: 0,
        ),
      ]),
    );

    session.start();

    expect(session.handleNoteInput('Db4'), isTrue);
  });

  test('GameSession finds the next note in an unordered score', () {
    final timeSource = FakeTimeSource();
    final session = GameSession(
      ticksEngine: TicksEngine(timeSource: timeSource),
      scoreEngine: ScoreEngine(),
      musicScore: _score([
        NoteModel(
          pitch: 'D4',
          duration: NoteDuration.quarter,
          absoluteTick: 480,
        ),
        NoteModel(pitch: 'C4', duration: NoteDuration.quarter, absoluteTick: 0),
      ]),
    );
    session.start();

    expect(session.handleNoteInput('C4'), isTrue);

    timeSource.advance(const Duration(milliseconds: 500));
    expect(session.handleNoteInput('D4'), isTrue);
  });

  test('GameSession handles a long score without scanning old notes', () {
    const noteCount = 5000;
    final timeSource = FakeTimeSource();
    final session = GameSession(
      ticksEngine: TicksEngine(timeSource: timeSource),
      scoreEngine: ScoreEngine(),
      musicScore: _score([
        for (var index = 0; index < noteCount; index++)
          NoteModel(
            pitch: 'C4',
            duration: NoteDuration.quarter,
            absoluteTick: index * TicksEngine.tpnq,
          ),
      ]),
    );
    session.start();
    timeSource.advance(
      Duration(
        milliseconds:
            (noteCount - 1) *
            TicksEngine.tpnq *
            60000 ~/
            (TicksEngine.tpnq * 120),
      ),
    );

    expect(session.handleNoteInput('C4'), isTrue);
    expect(session.scoreEngine.hitCount, 1);
  });

  test('GameSession finish is idempotent', () {
    final session = GameSession(
      ticksEngine: TicksEngine(),
      scoreEngine: ScoreEngine(),
      musicScore: _score([]),
    );
    var finishedTransitions = 0;
    session.onStateChange((state) {
      if (state == GameState.finished) finishedTransitions++;
    });

    session.finish();
    session.finish();
    session.finish();

    expect(session.isFinished, isTrue);
    expect(finishedTransitions, 1);
  });

  test('finish counts unresolved notes as misses', () {
    final session = _sessionWithNotes(['C4', 'D4', 'E4', 'F4']);
    session.start();

    expect(session.handleNoteInput('C4'), isTrue);
    session.finish();

    expect(session.scoreEngine.hitCount, 1);
    expect(session.scoreEngine.missCount, 3);
    expect(session.scoreEngine.getAccuracy(), 25.0);
    expect(session.currentCombo, 0);
    expect(session.hitHistory, [
      HitQuality.perfect,
      HitQuality.miss,
      HitQuality.miss,
      HitQuality.miss,
    ]);
  });

  test('finish does not count unresolved notes twice', () {
    final session = _sessionWithNotes(['C4', 'D4']);

    session.finish();
    session.finish();

    expect(session.scoreEngine.hitCount, 0);
    expect(session.scoreEngine.missCount, 2);
    expect(session.scoreEngine.getAccuracy(), 0.0);
  });

  test('finish preserves a perfect score when every note was hit', () {
    final session = _sessionWithNotes(['C4', 'D4', 'E4', 'F4']);
    session.start();

    for (final pitch in ['C4', 'D4', 'E4', 'F4']) {
      expect(session.handleNoteInput(pitch), isTrue);
    }
    session.finish();

    expect(session.scoreEngine.hitCount, 4);
    expect(session.scoreEngine.missCount, 0);
    expect(session.scoreEngine.getAccuracy(), 100.0);
  });

  test('finish retains misses caused by incorrect pitch', () {
    final session = _sessionWithNotes(['C4', 'D4', 'E4', 'F4']);
    session.start();

    expect(session.handleNoteInput('C#4'), isFalse);
    expect(session.handleNoteInput('D4'), isTrue);
    session.finish();

    expect(session.scoreEngine.hitCount, 1);
    expect(session.scoreEngine.missCount, 3);
    expect(session.scoreEngine.getAccuracy(), 25.0);
  });
}
