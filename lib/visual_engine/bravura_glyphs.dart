import 'package:flutter/material.dart';

import '../core/core.dart';

/// Utilidades para pintar un subconjunto de glifos SMuFL usando Bravura.
class BravuraGlyphs {
  static const String fontFamily = 'Bravura';

  static String clef(ClefType clefType) {
    switch (clefType) {
      case ClefType.treble:
        return String.fromCharCode(0xE050);
      case ClefType.bass:
        return String.fromCharCode(0xE062);
      case ClefType.alto:
        return String.fromCharCode(0xE05C);
    }
  }

  static String accidental(Accidental accidental) {
    switch (accidental) {
      case Accidental.natural:
        return String.fromCharCode(0xE261);
      case Accidental.sharp:
        return String.fromCharCode(0xE262);
      case Accidental.flat:
        return String.fromCharCode(0xE260);
      case Accidental.doubleSharp:
        return String.fromCharCode(0xE263);
      case Accidental.doubleFlat:
        return String.fromCharCode(0xE264);
    }
  }

  static String notehead(NoteDuration duration) {
    switch (duration) {
      case NoteDuration.whole:
        return String.fromCharCode(0xE0A2);
      case NoteDuration.half:
        return String.fromCharCode(0xE0A3);
      case NoteDuration.quarter:
      case NoteDuration.eighth:
      case NoteDuration.sixteenth:
        return String.fromCharCode(0xE0A4);
    }
  }

  static String individualNote(NoteDuration duration, {required bool stemUp}) {
    switch (duration) {
      case NoteDuration.whole:
        return String.fromCharCode(0xE1D2); // noteWhole
      case NoteDuration.half:
        return String.fromCharCode(stemUp ? 0xE1D3 : 0xE1D4); // noteHalfUp/Down
      case NoteDuration.quarter:
        return String.fromCharCode(stemUp ? 0xE1D5 : 0xE1D6); // noteQuarterUp/Down
      case NoteDuration.eighth:
        return String.fromCharCode(stemUp ? 0xE1D7 : 0xE1D8); // note8thUp/Down
      case NoteDuration.sixteenth:
        return String.fromCharCode(stemUp ? 0xE1D9 : 0xE1DA); // note16thUp/Down
    }
  }

  static String flag(NoteDuration duration, {required bool stemUp}) {
    switch (duration) {
      case NoteDuration.eighth:
        return String.fromCharCode(stemUp ? 0xE240 : 0xE241);
      case NoteDuration.sixteenth:
        return String.fromCharCode(stemUp ? 0xE242 : 0xE243);
      case NoteDuration.whole:
      case NoteDuration.half:
      case NoteDuration.quarter:
        return '';
    }
  }

  static String rest(NoteDuration duration) {
    switch (duration) {
      case NoteDuration.whole:
        return String.fromCharCode(0xE4E3);
      case NoteDuration.half:
        return String.fromCharCode(0xE4E4);
      case NoteDuration.quarter:
        return String.fromCharCode(0xE4E5);
      case NoteDuration.eighth:
        return String.fromCharCode(0xE4E6);
      case NoteDuration.sixteenth:
        return String.fromCharCode(0xE4E7);
    }
  }

  static TextPainter buildPainter(
    String glyph, {
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: fontFamily,
          package: null,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  static void paintCentered(
    Canvas canvas, {
    required String glyph,
    required Offset center,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    Offset offset = Offset.zero,
  }) {
    final painter = buildPainter(
      glyph,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
    painter.paint(
      canvas,
      Offset(
        center.dx - (painter.width / 2) + offset.dx,
        center.dy - (painter.height / 2) + offset.dy,
      ),
    );
  }
}
