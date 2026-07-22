import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/core.dart';
import 'staff_renderer.dart' as sr;
import 'note_visual.dart' as nv;
import 'animation_manager.dart' as am;

/// Renderizador visual principal usando Canvas
/// Versión OPTIMIZADA para móvil:
/// - Cache del pentagrama en Picture
/// - Pinceles estáticos (sin creación en paint)
/// - Dibujo eficiente de notas
class SMuFLRenderer extends CustomPainter {
  static const double compactStaffTop = 43;

  final TicksEngine? ticksEngine;
  final TimeSignature? timeSignature;
  final KeySignature? keySignature;
  final List<NoteModel> visibleNotes;
  final am.AnimationManager animationManager;
  final ClefType clefType;
  final bool showTimeSignature;
  final bool showKeySignature;
  final bool showBarLines;
  final bool showHitLine;
  final double? hitLineXOverride;
  final double? pixelsPerTick;

  final Color backgroundColor;
  final Color staffColor;
  final Color noteColor;

  // --- Cache del pentagrama (optimización principal) ---
  ui.Picture? _cachedStaffPicture;
  Size? _lastCacheSize;

  // --- Pinceles estáticos (no se crean en paint) ---
  static final Paint _backgroundPaint = Paint();
  static final Paint _hitLinePaint = Paint()
    ..color = Colors.red.withOpacity(0.8)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  SMuFLRenderer({
    this.ticksEngine,
    this.timeSignature,
    this.keySignature,
    this.visibleNotes = const [],
    required this.animationManager,
    this.clefType = ClefType.treble,
    this.showTimeSignature = true,
    this.showKeySignature = true,
    this.showBarLines = true,
    this.showHitLine = true,
    this.hitLineXOverride,
    this.pixelsPerTick,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.staffColor = Colors.black87,
    this.noteColor = Colors.black,
  });

  // ============================================================
  // CONSTRUCCIÓN DEL CACHE DEL PENTAGRAMA (solo una vez)
  // ============================================================

  void _buildStaffCache(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _backgroundPaint..color = backgroundColor,
    );

    // 2. Pentagrama, clave y compás
    _drawStaffWithElements(canvas, size);

    // 3. Guardar en cache
    _cachedStaffPicture = recorder.endRecording();
    _lastCacheSize = size;
  }

  // ============================================================
  // MÉTODO PAINT (optimizado)
  // ============================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // --- Dibujar cache del pentagrama (ultra-rápido) ---
    if (_cachedStaffPicture == null || _lastCacheSize != size) {
      _buildStaffCache(size);
    }
    canvas.drawPicture(_cachedStaffPicture!);

    // --- Calcular posición de la línea de beat ---
    final double leftMargin = 80.0;
    final double hitLineX = hitLineXOverride ?? _computeHitLineX(leftMargin);

    // --- Dibujar elementos dinámicos (notas, línea de beat, animaciones) ---
    _drawNotes(canvas, size, hitLineX);
    if (showHitLine) {
      _drawHitLine(canvas, hitLineX);
    }

    // --- Dibujar animaciones (feedback, combo, precisión) ---
    animationManager.updateAndDraw(canvas, size);
  }

  // ============================================================
  // DIBUJO DEL PENTAGRAMA (solo para el cache)
  // ============================================================

  void _drawStaffWithElements(Canvas canvas, Size size) {
    const double topMargin = compactStaffTop;
    const double leftMargin = 80;
    const double rightMargin = 40;

    // Dibujar pentagrama (solo las 5 líneas principales)
    final staffBounds = Rect.fromLTRB(
      leftMargin,
      topMargin,
      size.width - rightMargin,
      topMargin + 4 * sr.StaffRenderer.SPACE_HEIGHT,
    );
    sr.StaffRenderer.drawStaff(
      canvas,
      staffBounds,
      drawAdditionalLines: false,
    );

    // Dibujar clave musical (posicionada en B4, línea 3)
    final clefCenterY = topMargin + 2 * sr.StaffRenderer.SPACE_HEIGHT;
    final clefCenterX = leftMargin + 30;
    sr.StaffRenderer.drawClef(
      canvas,
      Offset(clefCenterX, clefCenterY),
      clefType,
    );

    // Calcular posiciones para armadura y compás
    final keySignatureStartX =
        sr.StaffRenderer.clefRightEdge(clefCenterX, clefType) +
        sr.StaffRenderer.CLEF_TO_KEY_SIGNATURE_GAP;
    final maxKeySignatureWidth = sr.StaffRenderer.maxKeySignatureLayoutWidth();
    final timeSignatureX = keySignatureStartX +
        maxKeySignatureWidth +
        sr.StaffRenderer.KEY_SIGNATURE_TIME_GAP;

    // Dibujar armadura (key signature)
    if (showKeySignature && keySignature != null) {
      sr.StaffRenderer.drawKeySignature(
        canvas,
        Offset(keySignatureStartX, topMargin),
        keySignature!,
        clefType,
      );
    }

    // Dibujar indicación de compás
    if (showTimeSignature && timeSignature != null) {
      sr.StaffRenderer.drawTimeSignature(
        canvas,
        Offset(timeSignatureX, clefCenterY - 22),
        timeSignature!,
      );
    }
  }

  // ============================================================
  // DIBUJO DE NOTAS (dinámico, cada frame)
  // ============================================================

  void _drawNotes(Canvas canvas, Size size, double hitLineX) {
    if (visibleNotes.isEmpty) return;

    const double staffTop = compactStaffTop;

    final sortedNotes = [...visibleNotes]
      ..sort((a, b) => a.absoluteTick.compareTo(b.absoluteTick));

    final baseTick = sortedNotes.first.absoluteTick;

    final ticksPerMeasure = _ticksPerMeasure();
    if (ticksPerMeasure <= 0) return;

    final pxPerTick = pixelsPerTick ?? 0.35;
    final firstXByMeasure = <int, double>{};
    final lastXByMeasure = <int, double>{};

    // Agrupar notas por barras (beams)
    final beamedGroups = _groupBeamedNotes(sortedNotes);

    // Dibujar cada nota
    for (final note in sortedNotes) {
      final noteX = hitLineX + ((note.absoluteTick - baseTick) * pxPerTick);
      final measure = note.absoluteTick ~/ ticksPerMeasure;

      firstXByMeasure.putIfAbsent(measure, () => noteX);
      lastXByMeasure[measure] = noteX;

      nv.NoteVisual().renderNote(
        canvas,
        note,
        Offset(noteX, staffTop),
        clefType,
      );
    }

    // Dibujar beams entre notas conectadas
    _drawBeams(canvas, beamedGroups, baseTick, pxPerTick, hitLineX, staffTop);

    // Dibujar líneas de compás entre compases
    if (showBarLines) {
      final measures = firstXByMeasure.keys.toList()..sort();
      for (int i = 0; i < measures.length - 1; i++) {
        final currentMeasure = measures[i];
        final nextMeasure = measures[i + 1];
        final lastX = lastXByMeasure[currentMeasure]!;
        final firstNextX = firstXByMeasure[nextMeasure]!;
        final barX = (lastX + firstNextX) / 2.0;

        sr.StaffRenderer.drawBarLine(
          canvas,
          Offset(barX, staffTop),
          4 * sr.StaffRenderer.SPACE_HEIGHT,
        );
      }
    }
  }

  // ============================================================
  // MÉTODOS AUXILIARES (sin cambios)
  // ============================================================

  int _ticksPerMeasure() {
    if (timeSignature == null) {
      return TicksEngine.tpnq * 4;
    }
    return (TicksEngine.tpnq * timeSignature!.numerator * 4) ~/
        timeSignature!.denominator;
  }

  double _computeHitLineX(double leftMargin) {
    return leftMargin + 180.0;
  }

  void _drawHitLine(Canvas canvas, double hitLineX) {
    const double staffTop = compactStaffTop;

    // Línea roja
    canvas.drawLine(
      Offset(hitLineX, staffTop),
      Offset(hitLineX, staffTop + 4 * sr.StaffRenderer.SPACE_HEIGHT),
      _hitLinePaint,
    );

    // Etiqueta "BEAT" (se crea cada vez, pero es texto pequeño)
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BEAT',
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(hitLineX - textPainter.width / 2, 40),
    );
  }

  // ============================================================
  // MÉTODOS DE BEAMS (sin cambios, pero optimizados)
  // ============================================================

  List<List<NoteModel>> _groupBeamedNotes(List<NoteModel> notes) {
    final groups = <List<NoteModel>>[];
    List<NoteModel>? currentGroup;

    for (final note in notes) {
      if (note.isRest) continue;

      if (note.beamType == BeamType.begin) {
        currentGroup = [note];
        groups.add(currentGroup);
      } else if (note.beamType == BeamType.continuation || note.beamType == BeamType.end) {
        if (currentGroup != null) {
          currentGroup.add(note);
        } else {
          currentGroup = [note];
          groups.add(currentGroup);
        }
      } else {
        currentGroup = null;
      }

      if (note.beamType == BeamType.end) {
        currentGroup = null;
      }
    }

    return groups;
  }

  void _drawBeams(
    Canvas canvas,
    List<List<NoteModel>> beamedGroups,
    int baseTick,
    double pxPerTick,
    double hitLineX,
    double staffTop,
  ) {
    // Pinceles estáticos para beams
    final stemPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final beamPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    for (final group in beamedGroups) {
      if (group.length < 2) continue;

      final noteOffsets = <Offset>[];
      final notePositions = <int>[];

      for (final note in group) {
        final noteX = hitLineX + ((note.absoluteTick - baseTick) * pxPerTick);
        final position = nv.NoteVisual.notePositions[nv.NoteVisual.basePitchKey(note.pitch)] ?? 5;
        final noteY = sr.StaffRenderer.getNoteYPosition(staffTop, position);
        noteOffsets.add(Offset(noteX, noteY));
        notePositions.add(position);
      }

      final firstPos = noteOffsets.first;
      final lastPos = noteOffsets.last;
      final avgPosition = notePositions.reduce((a, b) => a + b) / notePositions.length;
      final stemUp = avgPosition >= 4;
      final firstStemX = firstPos.dx + (stemUp ? 8 : -8);
      final lastStemX = lastPos.dx + (stemUp ? 8 : -8);
      final beamDirection = stemUp ? -1.0 : 1.0;

      const baseStemLength = 43.0;
      const beamSpacing = 7.5;
      const beamThickness = 6.0;
      const hookLength = 16.0;

      final naturalFirstBeamY = firstPos.dy + (beamDirection * baseStemLength);
      final naturalLastBeamY = lastPos.dy + (beamDirection * baseStemLength);
      final maxBeamDelta = 12.0;
      final clampedLastBeamY = naturalFirstBeamY +
          (naturalLastBeamY - naturalFirstBeamY).clamp(-maxBeamDelta, maxBeamDelta);

      final maxBeamLevel = group
          .map(_maxBeamLevelForNote)
          .fold<int>(1, (currentMax, value) => value > currentMax ? value : currentMax);
      final invertSecondaryBeamOffset = _shouldInvertSecondaryBeamOffset(group);
      final dottedEighthSixteenthPattern = _isDottedEighthSixteenthPattern(group);
      final normalizeStemLengthToPrimaryBeam =
          _isEighthTwoSixteenthsPattern(group) || dottedEighthSixteenthPattern;

      // Dibujar stems
      for (int i = 0; i < group.length; i++) {
        final noteOffset = noteOffsets[i];
        final note = group[i];
        final stemX = noteOffset.dx + (stemUp ? 8 : -8);
        final stemTargetLevel =
            normalizeStemLengthToPrimaryBeam ? 1 : _maxBeamLevelForNote(note);
        final stemTargetY = _beamYAtX(
          stemX,
          firstStemX,
          naturalFirstBeamY,
          lastStemX,
          clampedLastBeamY,
          beamDirection * beamSpacing * (stemTargetLevel - 1),
        );
        final stemEndY = stemTargetY;
        canvas.drawLine(
          Offset(stemX, noteOffset.dy),
          Offset(stemX, stemEndY),
          stemPaint,
        );
      }

      // Dibujar beam principal (nivel 1)
      canvas.drawLine(
        Offset(firstStemX, naturalFirstBeamY),
        Offset(lastStemX, clampedLastBeamY),
        beamPaint,
      );

      // Dibujar beams adicionales (niveles 2+)
      for (int level = 2; level <= maxBeamLevel; level++) {
        final levelOffset = (invertSecondaryBeamOffset && level == 2)
            ? -beamDirection * beamSpacing
            : beamDirection * beamSpacing * (level - 1);

        for (int i = 0; i < group.length - 1; i++) {
          if (!_hasContinuousBeamBetween(group[i], group[i + 1], level)) {
            continue;
          }

          final startX = noteOffsets[i].dx + (stemUp ? 8 : -8);
          final endX = noteOffsets[i + 1].dx + (stemUp ? 8 : -8);
          final startY = _beamYAtX(
            startX,
            firstStemX,
            naturalFirstBeamY,
            lastStemX,
            clampedLastBeamY,
            levelOffset,
          );
          final endY = _beamYAtX(
            endX,
            firstStemX,
            naturalFirstBeamY,
            lastStemX,
            clampedLastBeamY,
            levelOffset,
          );
          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), beamPaint);
        }

        for (int i = 0; i < group.length; i++) {
          final note = group[i];
          if (!_hasBeamLevel(note, level)) continue;

          final hasLeftConnection =
              i > 0 && _hasContinuousBeamBetween(group[i - 1], note, level);
          final hasRightConnection =
              i < group.length - 1 && _hasContinuousBeamBetween(note, group[i + 1], level);

          if (hasLeftConnection || hasRightConnection) continue;

          var hookToLeft = _effectiveBeamType(note, level) == BeamType.end;
          if (dottedEighthSixteenthPattern &&
              level == 2 &&
              note.duration == NoteDuration.sixteenth) {
            hookToLeft = i == group.length - 1;
          }
          final startX = noteOffsets[i].dx + (stemUp ? 8 : -8);
          final endX = hookToLeft ? startX - hookLength : startX + hookLength;
          final startY = _beamYAtX(
            startX,
            firstStemX,
            naturalFirstBeamY,
            lastStemX,
            clampedLastBeamY,
            levelOffset,
          );
          final endY = _beamYAtX(
            endX,
            firstStemX,
            naturalFirstBeamY,
            lastStemX,
            clampedLastBeamY,
            levelOffset,
          );
          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), beamPaint);
        }
      }
    }
  }

  int _maxBeamLevelForNote(NoteModel note) {
    var maxLevel = note.beamType.isBeamed ? 1 : 0;
    for (final entry in note.beamLevels.entries) {
      if (entry.value != BeamType.none && entry.key > maxLevel) {
        maxLevel = entry.key;
      }
    }
    if (maxLevel == 1 &&
        note.duration == NoteDuration.sixteenth &&
        note.beamType.isBeamed) {
      maxLevel = 2;
    }
    return maxLevel == 0 ? 1 : maxLevel;
  }

  bool _hasBeamLevel(NoteModel note, int level) {
    return _effectiveBeamType(note, level) != BeamType.none;
  }

  BeamType _effectiveBeamType(NoteModel note, int level) {
    if (level == 1) return note.beamType;
    final beamType = note.beamLevels[level];
    if (beamType != null) return beamType;
    if (level == 2 &&
        note.duration == NoteDuration.sixteenth &&
        note.beamType.isBeamed) {
      return BeamType.continuation;
    }
    return BeamType.none;
  }

  bool _hasContinuousBeamBetween(NoteModel left, NoteModel right, int level) {
    final leftType = _effectiveBeamType(left, level);
    final rightType = _effectiveBeamType(right, level);
    final leftConnectsRight =
        leftType == BeamType.begin || leftType == BeamType.continuation;
    final rightConnectsLeft =
        rightType == BeamType.continuation || rightType == BeamType.end;
    return leftConnectsRight && rightConnectsLeft;
  }

  bool _shouldInvertSecondaryBeamOffset(List<NoteModel> group) {
    if (_isEighthTwoSixteenthsPattern(group)) return true;
    return _isDottedEighthSixteenthPattern(group);
  }

  bool _isEighthTwoSixteenthsPattern(List<NoteModel> group) {
    if (group.length != 3) return false;
    final first = group[0].duration;
    final second = group[1].duration;
    final third = group[2].duration;
    final eighthThenTwoSixteenths = first == NoteDuration.eighth &&
        second == NoteDuration.sixteenth &&
        third == NoteDuration.sixteenth;
    final twoSixteenthsThenEighth = first == NoteDuration.sixteenth &&
        second == NoteDuration.sixteenth &&
        third == NoteDuration.eighth;
    return eighthThenTwoSixteenths || twoSixteenthsThenEighth;
  }

  bool _isDottedEighthSixteenthPattern(List<NoteModel> group) {
    if (group.length != 2) return false;
    final first = group[0];
    final second = group[1];
    final dottedEighthThenSixteenth = first.duration == NoteDuration.eighth &&
        first.isDotted &&
        second.duration == NoteDuration.sixteenth;
    final sixteenthThenDottedEighth = first.duration == NoteDuration.sixteenth &&
        second.duration == NoteDuration.eighth &&
        second.isDotted;
    return dottedEighthThenSixteenth || sixteenthThenDottedEighth;
  }

  double _beamYAtX(
    double x,
    double startX,
    double startY,
    double endX,
    double endY,
    double levelOffset,
  ) {
    if ((endX - startX).abs() < 0.001) {
      return startY + levelOffset;
    }
    final t = (x - startX) / (endX - startX);
    return startY + ((endY - startY) * t) + levelOffset;
  }

  // ============================================================
  // SHOULD REPAINT (optimizado)
  // ============================================================

  @override
  bool shouldRepaint(SMuFLRenderer oldDelegate) {
    // Solo repintar si realmente cambió algo importante
    return oldDelegate.visibleNotes != visibleNotes ||
        oldDelegate.pixelsPerTick != pixelsPerTick ||
        oldDelegate.hitLineXOverride != hitLineXOverride ||
        oldDelegate.showHitLine != showHitLine ||
        oldDelegate.timeSignature != timeSignature ||
        oldDelegate.keySignature != keySignature ||
        oldDelegate.clefType != clefType ||
        oldDelegate.showTimeSignature != showTimeSignature ||
        oldDelegate.showKeySignature != showKeySignature ||
        oldDelegate.showBarLines != showBarLines ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.staffColor != staffColor ||
        oldDelegate.noteColor != noteColor;
  }
}