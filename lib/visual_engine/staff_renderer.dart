import 'package:flutter/material.dart';
import '../core/core.dart';
import 'bravura_glyphs.dart';

/// Renderizador del pentagrama musical.
class StaffRenderer {
  static const int LINE_COUNT = 5;
  static const double SPACE_HEIGHT = 16.0;
  static const double STAFF_LINE_WIDTH = 1.5;
  static const double CLEF_FONT_SIZE = 42.0;
  static const Offset CLEF_OFFSET = Offset(-21, 15);
  static const double KEY_SIGNATURE_FONT_SIZE = 28.0;
  static const double KEY_SIGNATURE_SPACING = 12.0;
  static const double KEY_SIGNATURE_TIME_GAP = 10.0;
  static const double CLEF_TO_KEY_SIGNATURE_GAP = 8.0;

  // --- PINCELES ESTÁTICOS ---
  static final Paint _staffPaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = STAFF_LINE_WIDTH
    ..style = PaintingStyle.stroke;

  static final Paint _barLinePaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _finalBarLinePaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;

  static final Paint _ledgerPaint = Paint()
    ..color = Colors.black87
    ..strokeWidth = STAFF_LINE_WIDTH
    ..style = PaintingStyle.stroke;

  // --- TextPainter reutilizable para compás ---
  static final TextPainter _timeSigPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  static void drawStaff(
    Canvas canvas,
    Rect bounds, {
    bool drawAdditionalLines = true,
  }) {
    final top = bounds.top;
    final left = bounds.left;
    final right = bounds.right;

    for (int i = 0; i < LINE_COUNT; i++) {
      final y = top + (i * SPACE_HEIGHT);
      canvas.drawLine(Offset(left, y), Offset(right, y), _staffPaint);
    }

    if (drawAdditionalLines) {
      for (int i = 1; i <= 2; i++) {
        final y = top - (i * SPACE_HEIGHT);
        canvas.drawLine(Offset(left, y), Offset(right, y), _staffPaint);
      }
      for (int i = 1; i <= 2; i++) {
        final y = top + (LINE_COUNT - 1) * SPACE_HEIGHT + (i * SPACE_HEIGHT);
        canvas.drawLine(Offset(left, y), Offset(right, y), _staffPaint);
      }
    }
  }

  static void drawClef(
    Canvas canvas,
    Offset position,
    ClefType clefType,
  ) {
    BravuraGlyphs.paintCentered(
      canvas,
      glyph: BravuraGlyphs.clef(clefType),
      center: position,
      fontSize: CLEF_FONT_SIZE,
      color: Colors.black87,
      offset: CLEF_OFFSET,
    );
  }

  static void drawBarLine(
    Canvas canvas,
    Offset position,
    double height, {
    bool isDouble = false,
    bool isFinal = false,
  }) {
    if (isFinal) {
      canvas.drawLine(
        Offset(position.dx, position.dy),
        Offset(position.dx, position.dy + height),
        _finalBarLinePaint,
      );
      _barLinePaint.strokeWidth = 2.0;
      canvas.drawLine(
        Offset(position.dx + 3, position.dy),
        Offset(position.dx + 3, position.dy + height),
        _barLinePaint,
      );
    } else if (isDouble) {
      canvas.drawLine(
        Offset(position.dx, position.dy),
        Offset(position.dx, position.dy + height),
        _barLinePaint,
      );
      _barLinePaint.strokeWidth = 1.0;
      canvas.drawLine(
        Offset(position.dx + 3, position.dy),
        Offset(position.dx + 3, position.dy + height),
        _barLinePaint,
      );
    } else {
      canvas.drawLine(
        Offset(position.dx, position.dy),
        Offset(position.dx, position.dy + height),
        _barLinePaint,
      );
    }
  }

  static void drawTimeSignature(
    Canvas canvas,
    Offset position,
    TimeSignature timeSignature,
  ) {
    final centerY = position.dy;

    // Numerador
    _timeSigPainter.text = TextSpan(
      text: timeSignature.numerator.toString(),
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
    _timeSigPainter.layout();
    _timeSigPainter.paint(
      canvas,
      Offset(
        position.dx - _timeSigPainter.width / 2,
        centerY - _timeSigPainter.height / 2 - 2,
      ),
    );

    // Denominador
    _timeSigPainter.text = TextSpan(
      text: timeSignature.denominator.toString(),
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
    _timeSigPainter.layout();
    _timeSigPainter.paint(
      canvas,
      Offset(
        position.dx - _timeSigPainter.width / 2,
        centerY + _timeSigPainter.height / 2 - 2,
      ),
    );
  }

  static double getNoteYPosition(
    double staffTop,
    int notePosition,
  ) {
    return staffTop + (notePosition * SPACE_HEIGHT / 2);
  }

  static void drawKeySignature(
    Canvas canvas,
    Offset position,
    KeySignature keySignature,
    ClefType clefType,
  ) {
    if (keySignature.fifths == 0) return;

    final symbol = BravuraGlyphs.accidental(
      keySignature.isSharp ? Accidental.sharp : Accidental.flat,
    );
    final count = keySignature.alterationCount.clamp(0, 7);
    final staffPositions = _keySignatureStaffPositions(keySignature, clefType);
    final painter = BravuraGlyphs.buildPainter(
      symbol,
      fontSize: KEY_SIGNATURE_FONT_SIZE,
      color: Colors.black87,
    );
    double currentX = position.dx + (painter.width / 2);

    for (int i = 0; i < count; i++) {
      final y = getNoteYPosition(position.dy, staffPositions[i]);
      painter.paint(
        canvas,
        Offset(currentX - painter.width / 2, y - painter.height / 2),
      );
      currentX += KEY_SIGNATURE_SPACING;
    }
  }

  static List<int> _keySignatureStaffPositions(
    KeySignature keySignature,
    ClefType clefType,
  ) {
    final pitches = keySignature.isSharp
        ? _sharpKeySignaturePitches(clefType)
        : _flatKeySignaturePitches(clefType);
    return pitches
        .take(keySignature.alterationCount)
        .map((pitch) => _staffPositionForPitch(pitch, clefType))
        .toList();
  }

  static List<String> _sharpKeySignaturePitches(ClefType clefType) {
    switch (clefType) {
      case ClefType.treble:
        return const ['F5', 'C5', 'G5', 'D5', 'A4', 'E5', 'B4'];
      case ClefType.bass:
        return const ['F3', 'C3', 'G3', 'D3', 'A2', 'E3', 'B2'];
      case ClefType.alto:
        return const ['F4', 'C4', 'G4', 'D4', 'A3', 'E4', 'B3'];
    }
  }

  static List<String> _flatKeySignaturePitches(ClefType clefType) {
    switch (clefType) {
      case ClefType.treble:
        return const ['B4', 'E5', 'A4', 'D5', 'G4', 'C5', 'F4'];
      case ClefType.bass:
        return const ['B2', 'E3', 'A2', 'D3', 'G2', 'C3', 'F2'];
      case ClefType.alto:
        return const ['B3', 'E4', 'A3', 'D4', 'G3', 'C4', 'F3'];
    }
  }

  static int _staffPositionForPitch(String pitch, ClefType clefType) {
    final match = RegExp(r'^([A-G])(\d+)$').firstMatch(pitch);
    if (match == null) return 0;

    final noteName = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    final targetIndex = _diatonicPitchIndex(noteName, octave);
    final topLinePitch = switch (clefType) {
      ClefType.treble => ('F', 5),
      ClefType.bass => ('A', 3),
      ClefType.alto => ('G', 4),
    };
    final topLineIndex = _diatonicPitchIndex(topLinePitch.$1, topLinePitch.$2);
    return topLineIndex - targetIndex;
  }

  static int _diatonicPitchIndex(String noteName, int octave) {
    const noteOrder = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };
    return (octave * 7) + (noteOrder[noteName] ?? 0);
  }

  static double clefRightEdge(double clefCenterX, ClefType clefType) {
    final painter = BravuraGlyphs.buildPainter(
      BravuraGlyphs.clef(clefType),
      fontSize: CLEF_FONT_SIZE,
      color: Colors.black87,
    );
    final clefLeft = clefCenterX - (painter.width / 2) + CLEF_OFFSET.dx;
    return clefLeft + painter.width;
  }

  static double maxKeySignatureLayoutWidth() {
    final sharpPainter = BravuraGlyphs.buildPainter(
      BravuraGlyphs.accidental(Accidental.sharp),
      fontSize: KEY_SIGNATURE_FONT_SIZE,
      color: Colors.black87,
    );
    final flatPainter = BravuraGlyphs.buildPainter(
      BravuraGlyphs.accidental(Accidental.flat),
      fontSize: KEY_SIGNATURE_FONT_SIZE,
      color: Colors.black87,
    );
    final widestGlyphWidth =
        sharpPainter.width > flatPainter.width ? sharpPainter.width : flatPainter.width;
    return widestGlyphWidth + (KEY_SIGNATURE_SPACING * 6);
  }

  static void drawLedgerLine(
    Canvas canvas,
    Offset position,
    double width,
  ) {
    final left = position.dx - width / 2;
    final right = position.dx + width / 2;
    final y = position.dy;
    canvas.drawLine(Offset(left, y), Offset(right, y), _ledgerPaint);
  }

  static String getDebugInfo() {
    return '''
    StaffRenderer Debug:
    - Lines: $LINE_COUNT
    - Space Height: ${SPACE_HEIGHT}px
    - Total Staff Height: ${(LINE_COUNT - 1) * SPACE_HEIGHT}px
    - Line Width: ${STAFF_LINE_WIDTH}px
    ''';
  }
}