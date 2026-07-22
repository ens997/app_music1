// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_music1/main.dart';
import 'package:app_music1/providers/exercise_provider.dart';

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
}
