import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

void main() {
  test('Visual Engine Integration Test', () {
    // Test basic instantiation
    final animationManager = AnimationManager();
    final timeSignature = TimeSignature(4, 4);
    final ticksEngine = TicksEngine(initialBpm: 120);

    final testNotes = [
      NoteModel(
        pitch: 'C4',
        duration: NoteDuration.quarter,
        absoluteTick: 0,
        accidental: Accidental.natural,
      ),
    ];

    final renderer = SMuFLRenderer(
      ticksEngine: ticksEngine,
      timeSignature: timeSignature,
      visibleNotes: testNotes,
      animationManager: animationManager,
      clefType: ClefType.treble,
    );

    // Verify renderer is created successfully
    expect(renderer, isNotNull);
    expect(renderer.clefType, ClefType.treble);
    expect(renderer.visibleNotes, testNotes);
    expect(renderer.timeSignature, timeSignature);

    // Test animation manager
    animationManager.addHitFeedback(Offset(100, 100), HitQuality.perfect);
    expect(animationManager.feedbackAnimations.length, 1);

    // Test staff renderer constants
    expect(StaffRenderer.LINE_COUNT, 5);
    expect(StaffRenderer.SPACE_HEIGHT, 16.0);

    // Test note visual positions
    expect(NoteVisual.notePositions['C4'], 10);
    expect(NoteVisual.notePositions['A4'], 5);

    // Test hit quality scores
    expect(HitQuality.perfect.getScore(), 300);
    expect(HitQuality.great.getScore(), 200);
    expect(HitQuality.good.getScore(), 100);
    expect(HitQuality.miss.getScore(), 0);

    print('✅ Visual Engine Integration Test PASSED');
  });
}