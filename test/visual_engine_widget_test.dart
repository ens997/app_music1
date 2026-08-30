import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/visual_engine/visual_engine.dart';

void main() {
	testWidgets('BeatLine renders its label and occupies its parent', (
		WidgetTester tester,
	) async {
		await tester.pumpWidget(
			const MaterialApp(
				home: Scaffold(
					body: SizedBox(
						width: 240,
						height: 180,
						child: BeatLine(
							hitLineX: 80,
							staffTop: 43,
							beatColor: Colors.red,
							perfectWindowHalfWidth: 18,
							label: 'BEAT',
						),
					),
				),
			),
		);

		expect(tester.getSize(find.byType(BeatLine)), const Size(240, 180));
		expect(find.descendant(of: find.byType(BeatLine), matching: find.byType(CustomPaint)), findsOneWidget);
	});

	testWidgets('HitHistoryDisplay limits the visible history', (
		WidgetTester tester,
	) async {
		final history = List<HitQuality>.filled(5, HitQuality.perfect);

		await tester.pumpWidget(
			MaterialApp(
				home: Scaffold(
					body: HitHistoryDisplay(
						history: history,
						maxItems: 3,
						dotSize: 12,
					),
				),
			),
		);

		final dots = find.byWidgetPredicate(
			(widget) =>
					widget is Container &&
					widget.decoration is BoxDecoration &&
					(widget.decoration! as BoxDecoration).shape == BoxShape.circle,
		);
		expect(dots, findsNWidgets(3));
	});

	testWidgets('PianoInput sends the pressed white and black keys', (
		WidgetTester tester,
	) async {
		final pressedNotes = <String>[];

		await tester.pumpWidget(
			MaterialApp(
				home: Scaffold(
					body: PianoInput(
						enabled: true,
						notes: const ['C4', 'D4', 'E4'],
						onNotePressed: pressedNotes.add,
					),
				),
			),
		);

		await tester.tap(find.text('C4'));
		await tester.tapAt(const Offset(55, 30));

		expect(pressedNotes, contains('C4'));
		expect(pressedNotes, contains('C#4'));
	});
}

