import 'package:flutter_test/flutter_test.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

void main() {
  group('Visual Engine Tests', () {
    late AnimationManager animationManager;

    setUp(() {
      animationManager = AnimationManager();
    });

    test('StaffRenderer constants are correct', () {
      expect(StaffRenderer.LINE_COUNT, 5);
      expect(StaffRenderer.SPACE_HEIGHT, 16.0);
      expect(StaffRenderer.STAFF_LINE_WIDTH, 1.5);
    });

    test('NoteVisual notePositions contains expected notes', () {
      expect(NoteVisual.notePositions['C4'], 10);
      expect(NoteVisual.notePositions['A4'], 5);
      expect(NoteVisual.notePositions['F5'], 0);
    });

    test('AnimationManager initializes with empty lists', () {
      expect(animationManager.feedbackAnimations, isEmpty);
      expect(animationManager.comboAnimations, isEmpty);
      expect(animationManager.accuracyAnimations, isEmpty);
    });

    test('SMuFLRenderer initializes with required parameters', () {
      final renderer = SMuFLRenderer(
        animationManager: animationManager,
        clefType: ClefType.treble,
      );

      expect(renderer.clefType, ClefType.treble);
      expect(renderer.showTimeSignature, true);
      expect(renderer.showBarLines, true);
    });

    test('HitQuality enum has correct properties', () {
      expect(HitQuality.perfect.getScore(), 300);
      expect(HitQuality.great.getScore(), 200);
      expect(HitQuality.good.getScore(), 100);
      expect(HitQuality.miss.getScore(), 0);

      expect(HitQuality.perfect.displayName, isNotEmpty);
      expect(HitQuality.great.displayName, isNotEmpty);
    });
  });
}