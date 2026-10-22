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
}
