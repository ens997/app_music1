// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_music1/audio/piano_audio_service.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/game/metronome_controller.dart';
import 'package:app_music1/main.dart';
import 'package:app_music1/providers/exercise_provider.dart';
import 'package:app_music1/screens/game_screen.dart';

void main() {
  testWidgets('Music training app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ExerciseProvider(),
        child: const MusicTrainingApp(),
      ),
    );

    expect(find.text('Bienvenido al Entrenador Musical'), findsOneWidget);
    expect(find.textContaining('Elegir Ejercicios'), findsOneWidget);
  });

  testWidgets('GameScreen does not keep the empty placeholder when assets are available',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cargue un archivo MusicXML para comenzar.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('MetronomeController allows changing volume without reinitialization errors', () {
    final controller = MetronomeController(
      ticksEngine: TicksEngine(initialBpm: 80),
      timeSignature: const TimeSignature(4, 4),
      audioService: PianoAudioService(),
    );

    expect(() => controller.setVolume(0.7), returnsNormally);
    expect(controller.volume, closeTo(0.7, 0.0001));
  });
}
