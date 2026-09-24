import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/musical_engine/pitch_utils.dart';
import 'bravura_glyphs.dart';
import 'staff_renderer.dart';

class NoteVisual {
  static const Map<String, int> notePositions = {
    'G3': 14,
    'A3': 13,
    'B3': 12,
    'C4': 10,
    'D4': 9,
    'E4': 8,
    'F4': 7,
    'G4': 6,
    'A4': 5,
    'B4': 4,
    'C5': 3,
    'D5': 2,
    'E5': 1,
    'F5': 0,
    'G5': -1,
    'A5': -2,
    'B5': -3,
    'C6': -4,
    'D6': -5,
  };

  static final Paint _stemPaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _dotPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  static final Paint _ledgerPaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = StaffRenderer.STAFF_LINE_WIDTH
    ..style = PaintingStyle.stroke;

  static final TextPainter _labelPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  static void drawNote(
    Canvas canvas,
    NoteModel note,
    Offset headPosition,
    double staffTop,
    Color color,
  ) {
    if (note.isRest) {
      _drawRest(canvas, note, headPosition.dx, staffTop, color);
      return;
    }

    final staffPosition = notePositions[basePitchKey(note.pitch)] ?? 5;
    final headX = headPosition.dx;
    final headY = headPosition.dy;

    _drawLedgerLines(canvas, headX, staffTop, staffPosition);

    var fillColor = color;
    if (note.isHit) {
      fillColor = const Color(0xFF4ecca3);
    } else if (note.isMissed) {
      fillColor = const Color(0xFFe94560);
    }

    // 4 argumentos: canvas, Offset, NoteDuration, Color
    _drawNoteHead(canvas, Offset(headX, headY), note.duration, fillColor);

    if (note.isDotted && _supportsAugmentationDot(note.duration)) {
      _drawAugmentationDot(canvas, Offset(headX, headY), fillColor);
    }

    _drawStem(
      canvas,
      Offset(headX, headY),
      note.duration,
      fillColor,
      staffPosition,
      note.beamType,
    );

    if (note.displayAccidental) {
      _drawAccidental(canvas, Offset(headX, headY), note.accidental);
    }

    _drawNoteLabel(canvas, Offset(headX, headY - 45), note);
  }

  static String basePitchKey(String pitch) {
    final parsed = PitchUtils.parse(pitch);
    return parsed == null ? pitch : '${parsed.note}${parsed.octave}';
  }

  static void _drawLedgerLines(
    Canvas canvas,
    double noteX,
    double staffTop,
    int position,
  ) {
    const ledgerWidth = 35.0;

    if (position >= 10) {
      for (
        int ledgerPosition = 10;
        ledgerPosition <= position;
        ledgerPosition += 2
      ) {
        final ledgerY = StaffRenderer.getNoteYPosition(
          staffTop,
          ledgerPosition,
        );
        StaffRenderer.drawLedgerLine(
          canvas,
          Offset(noteX, ledgerY),
          ledgerWidth,
        );
      }
    }

    if (position <= -2) {
      for (
        int ledgerPosition = -2;
        ledgerPosition >= position;
        ledgerPosition -= 2
      ) {
        final ledgerY = StaffRenderer.getNoteYPosition(
          staffTop,
          ledgerPosition,
        );
        StaffRenderer.drawLedgerLine(
          canvas,
          Offset(noteX, ledgerY),
          ledgerWidth,
        );
      }
    }
  }

  static void _drawNoteHead(
    Canvas canvas,
    Offset position,
    NoteDuration duration,
    Color color,
  ) {
    final glyph = BravuraGlyphs.notehead(duration);
    final headScale = 1.25;
    final fontSize = duration == NoteDuration.whole
        ? StaffRenderer.SPACE_HEIGHT * 2.5 * headScale
        : StaffRenderer.SPACE_HEIGHT * 2.25 * headScale;
    final offset = duration == NoteDuration.whole
        ? const Offset(0, -1)
        : const Offset(0, -0.5);

    BravuraGlyphs.paintCentered(
      canvas,
      glyph: glyph,
      center: position,
      fontSize: fontSize,
      color: color,
      offset: offset,
    );
  }

  static void _drawStem(
    Canvas canvas,
    Offset position,
    NoteDuration duration,
    Color color,
    int notePosition,
    BeamType beamType,
  ) {
    if (duration == NoteDuration.whole) return;
    if (beamType.isBeamed) return;

    if (_stemPaint.color != color) {
      _stemPaint.color = color;
    }

    final stemUp = notePosition >= 4;
    final stemLength = StaffRenderer.SPACE_HEIGHT * 3.5;
    final headAnchorX = StaffRenderer.SPACE_HEIGHT * 0.375;
    final headAnchorYOffset = StaffRenderer.SPACE_HEIGHT * 0.08;

    final startX = position.dx + (stemUp ? headAnchorX : -headAnchorX);
    final startY =
        position.dy + (stemUp ? headAnchorYOffset : -headAnchorYOffset);
    final endY = startY + (stemUp ? -stemLength : stemLength);

    canvas.drawLine(Offset(startX, startY), Offset(startX, endY), _stemPaint);

    if (duration == NoteDuration.eighth || duration == NoteDuration.sixteenth) {
      _drawFlag(canvas, Offset(startX, endY), stemUp, duration, color);
    }
  }

  static void _drawFlag(
    Canvas canvas,
    Offset stemEnd,
    bool stemUp,
    NoteDuration duration,
    Color color,
  ) {
    final glyph = BravuraGlyphs.flag(duration, stemUp: stemUp);
    if (glyph.isEmpty) return;

    final flagFontSize = StaffRenderer.SPACE_HEIGHT * 2.2;
    final xOffset = StaffRenderer.SPACE_HEIGHT * (stemUp ? 0.02 : -0.02);
    final yOffset = StaffRenderer.SPACE_HEIGHT * (stemUp ? 0.02 : -0.02);

    final painter = BravuraGlyphs.buildPainter(
      glyph,
      fontSize: flagFontSize,
      color: color,
    );

    final stemHalfWidth = 1.0;
    final horizontalAttachment = StaffRenderer.SPACE_HEIGHT * 0.08;
    final verticalAttachment = StaffRenderer.SPACE_HEIGHT * 0.72;
    final manualHorizontalShift = painter.width * 0.10;

    final topLeft = Offset(
      stemUp
          ? stemEnd.dx -
                stemHalfWidth -
                horizontalAttachment +
                xOffset +
                manualHorizontalShift
          : stemEnd.dx +
                stemHalfWidth -
                horizontalAttachment +
                xOffset -
                manualHorizontalShift,
      stemUp
          ? stemEnd.dy - verticalAttachment + yOffset
          : stemEnd.dy - verticalAttachment + yOffset,
    );
    painter.paint(canvas, topLeft);
  }

  static void _drawAccidental(
    Canvas canvas,
    Offset position,
    Accidental accidental,
  ) {
    final metrics = _accidentalMetrics(accidental);
    final manualVerticalShift = metrics.fontSize * 0.05;
    BravuraGlyphs.paintCentered(
      canvas,
      glyph: BravuraGlyphs.accidental(accidental),
      center: position,
      fontSize: metrics.fontSize,
      color: Colors.black87,
      offset: Offset(metrics.xOffset, metrics.yOffset + manualVerticalShift),
    );
  }

  static bool _supportsAugmentationDot(NoteDuration duration) {
    return duration == NoteDuration.half ||
        duration == NoteDuration.quarter ||
        duration == NoteDuration.eighth;
  }

  static void _drawAugmentationDot(
    Canvas canvas,
    Offset position,
    Color color,
  ) {
    final radius = StaffRenderer.SPACE_HEIGHT * 0.17;
    final center = Offset(
      position.dx + StaffRenderer.SPACE_HEIGHT * 0.82,
      position.dy - StaffRenderer.SPACE_HEIGHT * 0.03,
    );

    if (_dotPaint.color != color) {
      _dotPaint.color = color;
    }
    canvas.drawCircle(center, radius, _dotPaint);
  }

  static ({double fontSize, double xOffset, double yOffset}) _accidentalMetrics(
    Accidental accidental,
  ) {
    final fontSize = StaffRenderer.SPACE_HEIGHT * 1.75;
    final xOffset = -StaffRenderer.SPACE_HEIGHT * 0.8;

    switch (accidental) {
      case Accidental.sharp:
        return (
          fontSize: fontSize,
          xOffset: xOffset,
          yOffset: -StaffRenderer.SPACE_HEIGHT * 0.08,
        );
      case Accidental.flat:
        return (
          fontSize: fontSize,
          xOffset: xOffset,
          yOffset: StaffRenderer.SPACE_HEIGHT * 0.10,
        );
      case Accidental.doubleSharp:
        return (
          fontSize: fontSize,
          xOffset: xOffset - (StaffRenderer.SPACE_HEIGHT * 0.05),
          yOffset: -StaffRenderer.SPACE_HEIGHT * 0.02,
        );
      case Accidental.doubleFlat:
        return (
          fontSize: fontSize,
          xOffset: xOffset,
          yOffset: StaffRenderer.SPACE_HEIGHT * 0.10,
        );
      case Accidental.natural:
        return (
          fontSize: fontSize,
          xOffset: xOffset,
          yOffset: -StaffRenderer.SPACE_HEIGHT * 0.02,
        );
    }
  }

  static void _drawNoteLabel(Canvas canvas, Offset position, NoteModel note) {
    final text = '${note.noteName}${note.octave}';
    _labelPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.blue,
        fontWeight: FontWeight.w600,
      ),
    );
    _labelPainter.layout();
    _labelPainter.paint(
      canvas,
      Offset(position.dx - _labelPainter.width / 2, position.dy),
    );
  }

  static void _drawRest(
    Canvas canvas,
    NoteModel note,
    double x,
    double staffTop,
    Color color,
  ) {
    final restY = StaffRenderer.getNoteYPosition(staffTop, 5);
    final glyph = BravuraGlyphs.rest(note.duration);
    final fontSize = switch (note.duration) {
      NoteDuration.whole => 34.0,
      NoteDuration.half => 34.0,
      NoteDuration.quarter => 38.0,
      NoteDuration.eighth => 38.0,
      NoteDuration.sixteenth => 40.0,
    };

    BravuraGlyphs.paintCentered(
      canvas,
      glyph: glyph,
      center: Offset(x, restY),
      fontSize: fontSize,
      color: color,
      offset: const Offset(0, -2),
    );
  }
}
