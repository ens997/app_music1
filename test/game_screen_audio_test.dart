import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/instrument_audio_output.dart';
import 'package:app_music1/audio/audio_service_lifecycle.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/screens/game_screen.dart';
import 'package:app_music1/visual_engine/widgets/piano_input.dart';

const _scoreXml = '''
<score-partwise>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

String _scoreWithManyNotes(int noteCount) {
  final notes = List.filled(noteCount, '''
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
      </note>
    ''').join();
  return '''
    <score-partwise>
      <part id="P1">
        <measure number="1">
          <attributes><divisions>1</divisions></attributes>
          $notes
        </measure>
      </part>
    </score-partwise>
  ''';
}

class _FakeInstrumentAudioOutput implements InstrumentAudioOutput {
  int initializeCalls = 0;
  int disposeCalls = 0;
  final List<String> playedNotes = [];
  Completer<void>? initializeGate;
  AudioServiceState _state = AudioServiceState.idle;

  @override
  AudioServiceState get state => _state;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    _state = AudioServiceState.initializing;
    await initializeGate?.future;
    _state = AudioServiceState.ready;
  }

  @override
  Future<void> playNote(String pitch, {double volume = 0.85}) async {
    playedNotes.add(pitch);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _state = AudioServiceState.disposed;
  }
}

class _FakeSustainedInstrumentAudioOutput extends _FakeInstrumentAudioOutput
    implements SustainedInstrumentAudioOutput {
  final List<String> noteEvents = [];
  int _nextVoiceId = 0;

  @override
  Future<int?> noteOn(String pitch, {double volume = 0.85}) async {
    noteEvents.add('on:$pitch');
    return ++_nextVoiceId;
  }

  @override
  Future<void> noteOff(int voiceId) async {
    noteEvents.add('off:$voiceId');
  }
}

void main() {
  testWidgets('GameScreen delegates note audio to its injected backend', (
    tester,
  ) async {
    final output = _FakeInstrumentAudioOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          preloadedContent: _scoreXml,
          timeSource: FakeTimeSource(),
          instrumentAudioOutput: output,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(output.initializeCalls, 1);
    expect(find.byType(PianoInput), findsOneWidget);

    final startButton = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Iniciar',
      ),
    );
    startButton.onPressed!();
    await tester.pump();

    final piano = tester.widget<PianoInput>(find.byType(PianoInput));
    expect(piano.enabled, isTrue);
    final c4Button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.descendant(
          of: find.byType(PianoInput),
          matching: find.text('C4'),
        ),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(c4Button.onPressed, isNotNull);
    c4Button.onPressed!();
    await tester.pump();

    expect(output.playedNotes, ['C4']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(output.disposeCalls, 1);
  });

  testWidgets('GameScreen holds and releases notes for sustained backends', (
    tester,
  ) async {
    final output = _FakeSustainedInstrumentAudioOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          preloadedContent: _scoreXml,
          timeSource: FakeTimeSource(),
          instrumentAudioOutput: output,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final startButton = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Iniciar',
      ),
    );
    startButton.onPressed!();
    await tester.pump();

    final piano = tester.widget<PianoInput>(find.byType(PianoInput));
    expect(piano.enabled, isTrue);
    expect(piano.onNoteDown, isNotNull);
    piano.onNoteDown!('C4', 1);
    await tester.pump();
    expect(output.noteEvents, ['on:C4']);

    piano.onNoteUp!('C4', 1);
    await tester.pump();
    expect(output.noteEvents, ['on:C4', 'off:1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('GameScreen loads the score while audio initializes', (
    tester,
  ) async {
    final output = _FakeInstrumentAudioOutput()
      ..initializeGate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          preloadedContent: _scoreXml,
          instrumentAudioOutput: output,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(output.initializeCalls, 1);
    expect(find.byType(PianoInput), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(output.disposeCalls, 0);

    output.initializeGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(output.disposeCalls, 1);
  });

  testWidgets(
    'auto-scroll updates do not restart scroll activity every frame',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final output = _FakeInstrumentAudioOutput();
      var scrollUpdates = 0;
      var scrollStarts = 0;
      var scrollEnds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                if (notification is ScrollUpdateNotification) scrollUpdates++;
                if (notification is ScrollStartNotification) scrollStarts++;
                if (notification is ScrollEndNotification) scrollEnds++;
              }
              return false;
            },
            child: GameScreen(
              preloadedContent: _scoreWithManyNotes(16),
              timeSource: FakeTimeSource(),
              instrumentAudioOutput: output,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final startButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Iniciar',
        ),
      );
      startButton.onPressed!();
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(scrollUpdates, greaterThan(0));
      expect(scrollStarts, 1);
      expect(scrollEnds, 0);

      final updatesBeforeNote = scrollUpdates;
      final piano = tester.widget<PianoInput>(find.byType(PianoInput));
      piano.onNotePressed('C4');
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(scrollUpdates, greaterThan(updatesBeforeNote));
      expect(scrollStarts, 1);
      expect(scrollEnds, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
