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
}
