import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

NoteModel _note({
	String pitch = 'C4',
	NoteDuration duration = NoteDuration.quarter,
	int absoluteTick = 0,
	bool isRest = false,
	BeamType beamType = BeamType.none,
}) {
	return NoteModel(
		pitch: pitch,
		duration: duration,
		absoluteTick: absoluteTick,
		isRest: isRest,
		beamType: beamType,
	);
}

void main() {
	group('NoteVisual', () {
		test('removes accidentals while preserving octave', () {
			expect(NoteVisual.basePitchKey('C#4'), 'C4');
			expect(NoteVisual.basePitchKey('Bb3'), 'B3');
			expect(NoteVisual.basePitchKey('D5'), 'D5');
		});

		test('falls back to the original value for invalid pitches', () {
			expect(NoteVisual.basePitchKey('invalid'), 'invalid');
		});
	});

	group('StaffRenderer', () {
		test('maps staff positions to half-space increments', () {
			expect(StaffRenderer.getNoteYPosition(43, 0), 43);
			expect(StaffRenderer.getNoteYPosition(43, 2), 59);
			expect(StaffRenderer.getNoteYPosition(43, -2), 27);
		});
	});

	group('AnimationManager', () {
		test('adds feedback and accuracy animations', () {
			final manager = AnimationManager();

			manager.addHitFeedback(const Offset(20, 30), HitQuality.perfect);
			manager.addAccuracyAnimation(
				const Offset(20, 30),
				HitQuality.great,
				-24,
			);

			expect(manager.feedbackAnimations, hasLength(1));
			expect(manager.accuracyAnimations, hasLength(1));
			expect(manager.accuracyAnimations.single.text, contains('24ms'));
		});

		test('only adds combo feedback at combo five or higher', () {
			final manager = AnimationManager();

			manager.addComboAnimation(const Offset(0, 0), 4);
			expect(manager.comboAnimations, isEmpty);

			manager.addComboAnimation(const Offset(0, 0), 5);
			expect(manager.comboAnimations, hasLength(1));
			expect(manager.comboAnimations.single.text, 'Combo x5');
		});

		test('clearAll removes every animation type', () {
			final manager = AnimationManager();
			manager.addHitFeedback(Offset.zero, HitQuality.good);
			manager.addComboAnimation(Offset.zero, 5);
			manager.addAccuracyAnimation(Offset.zero, HitQuality.good, 10);

			manager.clearAll();

			expect(manager.feedbackAnimations, isEmpty);
			expect(manager.comboAnimations, isEmpty);
			expect(manager.accuracyAnimations, isEmpty);
		});
	});

	group('SMuFLRenderer', () {
		test('paints a score without throwing', () async {
			final manager = AnimationManager();
			final layouts = [
				NoteLayout(_note(pitch: 'C4'), const Offset(220, 123)),
				NoteLayout(
					_note(
						pitch: 'D#4',
						duration: NoteDuration.eighth,
						beamType: BeamType.begin,
					),
					const Offset(280, 107),
				),
				NoteLayout(
					_note(
						pitch: 'E4',
						duration: NoteDuration.eighth,
						absoluteTick: 240,
						beamType: BeamType.end,
					),
					const Offset(320, 99),
				),
				NoteLayout(
					_note(isRest: true, absoluteTick: 480),
					const Offset(360, 123),
				),
			];
			final painter = SMuFLRenderer(
				timeSignature: TimeSignature(4, 4),
				keySignature: const KeySignature(fifths: 1),
				noteLayouts: layouts,
				animationManager: manager,
				hitLineXOverride: 180,
				scrollOffset: 0,
				viewportWidth: 640,
			);
			final recorder = ui.PictureRecorder();
			final canvas = Canvas(recorder);

			expect(
				() => painter.paint(canvas, const Size(640, 180)),
				returnsNormally,
			);
			final picture = recorder.endRecording();
			final image = await picture.toImage(640, 180);
			expect(image.width, 640);
			expect(image.height, 180);
			image.dispose();
			picture.dispose();
		});

		test('repaints when note layouts or scroll changes', () {
			final manager = AnimationManager();
			final layouts = [
				NoteLayout(_note(), const Offset(200, 100)),
			];
			final painter = SMuFLRenderer(
				noteLayouts: layouts,
				animationManager: manager,
				scrollOffset: 0,
				viewportWidth: 300,
			);
			final samePainter = SMuFLRenderer(
				noteLayouts: layouts,
				animationManager: manager,
				scrollOffset: 0,
				viewportWidth: 300,
			);
			final movedPainter = SMuFLRenderer(
				noteLayouts: layouts,
				animationManager: manager,
				scrollOffset: 20,
				viewportWidth: 300,
			);

			expect(painter.shouldRepaint(samePainter), isFalse);
			expect(painter.shouldRepaint(movedPainter), isTrue);
		});
	});
}
