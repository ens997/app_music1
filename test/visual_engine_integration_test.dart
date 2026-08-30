import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

void main() {
	testWidgets('visual score composition renders together', (
		WidgetTester tester,
	) async {
		final manager = AnimationManager();
		final notes = [
			NoteModel(
				pitch: 'C4',
				duration: NoteDuration.quarter,
				absoluteTick: 0,
			),
			NoteModel(
				pitch: 'D#4',
				duration: NoteDuration.eighth,
				absoluteTick: 480,
				displayAccidental: true,
				accidental: Accidental.sharp,
				beamType: BeamType.begin,
			),
			NoteModel(
				pitch: 'E4',
				duration: NoteDuration.eighth,
				absoluteTick: 720,
				beamType: BeamType.end,
			),
			NoteModel(
				pitch: 'C4',
				duration: NoteDuration.half,
				absoluteTick: 960,
				isRest: true,
			),
		];
		final layouts = [
			NoteLayout(notes[0], const Offset(220, 123)),
			NoteLayout(notes[1], const Offset(300, 107)),
			NoteLayout(notes[2], const Offset(340, 99)),
			NoteLayout(notes[3], const Offset(400, 123)),
		];

		await tester.pumpWidget(
			MaterialApp(
				home: Scaffold(
					body: SizedBox(
						width: 640,
						height: 240,
						child: Stack(
							children: [
								CustomPaint(
									size: const Size(640, 180),
									painter: SMuFLRenderer(
										timeSignature: TimeSignature(4, 4),
										keySignature: const KeySignature(fifths: 1),
										noteLayouts: layouts,
										animationManager: manager,
										showHitLine: true,
										hitLineXOverride: 180,
									),
								),
								const BeatLine(
									hitLineX: 180,
									staffTop: SMuFLRenderer.compactStaffTop,
									beatColor: Colors.red,
									perfectWindowHalfWidth: 18,
								),
								const Positioned(
									left: 4,
									top: 4,
									child: HitHistoryDisplay(
										history: [HitQuality.perfect, HitQuality.good],
									),
								),
							],
						),
					),
				),
			),
		);

		final scorePaint = find.byWidgetPredicate(
			(widget) =>
					widget is CustomPaint && widget.painter is SMuFLRenderer,
		);
		expect(scorePaint, findsOneWidget);
		expect(find.byType(HitHistoryDisplay), findsOneWidget);

		final recorder = ui.PictureRecorder();
		final canvas = Canvas(recorder);
		final painter = tester.widget<CustomPaint>(scorePaint).painter!;
		expect(() => painter.paint(canvas, const Size(640, 180)), returnsNormally);
		final picture = recorder.endRecording();
		final image = await picture.toImage(640, 180);
		expect(image.width, 640);
		expect(image.height, 180);
		image.dispose();
		picture.dispose();
	});
}
