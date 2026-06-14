import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

void main() {
  group('Visual Engine Widget Tests', () {
    late AnimationManager animationManager;
    late TimeSignature timeSignature;
    late List<NoteModel> testNotes;

    setUp(() {
      animationManager = AnimationManager();
      timeSignature = TimeSignature(4, 4);
      testNotes = [
        NoteModel(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          absoluteTick: 0,
          accidental: Accidental.natural,
        ),
        NoteModel(
          pitch: 'E4',
          duration: NoteDuration.half,
          absoluteTick: 480,
          accidental: Accidental.sharp,
        ),
      ];
    });

    testWidgets('SMuFLRenderer renders without errors', (WidgetTester tester) async {
      final renderer = SMuFLRenderer(
        animationManager: animationManager,
        timeSignature: timeSignature,
        visibleNotes: testNotes,
        clefType: ClefType.treble,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: renderer,
            size: const Size(800, 400),
          ),
        ),
      );

      // Verify the widget renders without throwing exceptions
      expect(find.byType(CustomPaint), findsWidgets); // at least one instance

      // Test that we can repaint
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('SMuFLRenderer handles different clef types', (WidgetTester tester) async {
      for (final clefType in ClefType.values) {
        final renderer = SMuFLRenderer(
          animationManager: animationManager,
          clefType: clefType,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              painter: renderer,
              size: const Size(600, 300),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
        expect(renderer.clefType, clefType);
      }
    });

    testWidgets('SMuFLRenderer handles empty note list', (WidgetTester tester) async {
      final renderer = SMuFLRenderer(
        animationManager: animationManager,
        visibleNotes: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: renderer,
            size: const Size(600, 300),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('SMuFLRenderer handles null time signature', (WidgetTester tester) async {
      final renderer = SMuFLRenderer(
        animationManager: animationManager,
        timeSignature: null,
        showTimeSignature: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: renderer,
            size: const Size(600, 300),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AnimationManager integrates with SMuFLRenderer', (WidgetTester tester) async {
      final renderer = SMuFLRenderer(
        animationManager: animationManager,
      );

      // Add various animations
      animationManager.addHitFeedback(Offset(200, 150), HitQuality.perfect);
      animationManager.addComboAnimation(Offset(300, 150), 8);
      animationManager.addAccuracyAnimation(Offset(400, 150), HitQuality.great, -15);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: renderer,
            size: const Size(600, 300),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      // Verify animations were added
      expect(animationManager.feedbackAnimations.length, 1);
      expect(animationManager.comboAnimations.length, 1);
      expect(animationManager.accuracyAnimations.length, 1);
    });

    testWidgets('SMuFLRenderer handles different sizes', (WidgetTester tester) async {
      final testSizes = [
        const Size(400, 200),
        const Size(800, 400),
        const Size(1200, 600),
        const Size(0, 0), // Edge case
      ];

      for (final size in testSizes) {
        final renderer = SMuFLRenderer(
          animationManager: animationManager,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CustomPaint(
              painter: renderer,
              size: size,
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsOneWidget);
      }
    });

    testWidgets('SMuFLRenderer with all optional parameters', (WidgetTester tester) async {
      final ticksEngine = TicksEngine(initialBpm: 120);

      final renderer = SMuFLRenderer(
        ticksEngine: ticksEngine,
        timeSignature: timeSignature,
        visibleNotes: testNotes,
        animationManager: animationManager,
        clefType: ClefType.bass,
        showTimeSignature: false,
        showBarLines: false,
        backgroundColor: Colors.blue,
        staffColor: Colors.red,
        noteColor: Colors.green,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: renderer,
            size: const Size(800, 400),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
      expect(renderer.ticksEngine, ticksEngine);
      expect(renderer.timeSignature, timeSignature);
      expect(renderer.visibleNotes, testNotes);
      expect(renderer.clefType, ClefType.bass);
      expect(renderer.showTimeSignature, false);
      expect(renderer.showBarLines, false);
      expect(renderer.backgroundColor, Colors.blue);
      expect(renderer.staffColor, Colors.red);
      expect(renderer.noteColor, Colors.green);
    });
  });
}