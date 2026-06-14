import 'package:flutter/material.dart';
import '../core/core.dart';
import 'staff_renderer.dart' as sr;
import 'note_visual.dart' as nv;
import 'animation_manager.dart' as am;

/// Renderizador visual principal usando Canvas
/// Orquesta StaffRenderer, NoteVisual y AnimationManager
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

  /// Permite controlar la escala horizontal de la partitura.
  /// Si se proporciona, ignora el ancho disponible del canvas
  /// y dibuja las notas según "px por tick" fijo.
  final double? pixelsPerTick;

  // Colores personalizables
  final Color backgroundColor;
  final Color staffColor;
  final Color noteColor;

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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // 1. Dibujar fondo
    _drawBackground(canvas, size);

    // 2. Calcular posición de la línea de beat en base a la primera nota
    final double leftMargin = 80.0;
    final double hitLineX = hitLineXOverride ?? _computeHitLineX(leftMargin);

    // 3. Dibujar pentagrama, notas y línea de beat
    _drawStaffWithElements(canvas, size);
    _drawNotes(canvas, size, hitLineX);
    if (showHitLine) {
      _drawHitLine(canvas, size, hitLineX);
    }

    // 4. Actualizar animaciones
    animationManager.updateAnimations();
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );
  }

  void _drawStaffWithElements(Canvas canvas, Size size) {
    const double topMargin = compactStaffTop;
    const double leftMargin = 80;
    const double rightMargin = 40;

    // Dibujar pentagrama (solo las 5 lineas principales)
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

    // Dibujar clave musical (posicionada en B4, linea 3)
    final clefCenterY = topMargin + 2 * sr.StaffRenderer.SPACE_HEIGHT;
    final clefCenterX = leftMargin + 30;
    sr.StaffRenderer.drawClef(
      canvas,
      Offset(clefCenterX, clefCenterY),
      clefType,
    );

    // La armadura comienza inmediatamente despues de la clave, con separacion convencional.
    final keySignatureStartX =
        sr.StaffRenderer.clefRightEdge(clefCenterX, clefType) +
        sr.StaffRenderer.CLEF_TO_KEY_SIGNATURE_GAP;
    final maxKeySignatureWidth = sr.StaffRenderer.maxKeySignatureLayoutWidth();
    final timeSignatureX = keySignatureStartX +
        maxKeySignatureWidth +
        sr.StaffRenderer.KEY_SIGNATURE_TIME_GAP;

    // Dibujar armadura (key signature) con posicionamiento convencional.
    if (showKeySignature && keySignature != null) {
      sr.StaffRenderer.drawKeySignature(
        canvas,
        Offset(keySignatureStartX, topMargin),
        keySignature!,
        clefType,
      );
    }

    // Dibujar indicacion de compas (alineada verticalmente con la clave)
    if (showTimeSignature && timeSignature != null) {
      sr.StaffRenderer.drawTimeSignature(
        canvas,
        Offset(timeSignatureX, clefCenterY - 22),
        timeSignature!,
      );
    }
  }

  int _ticksPerMeasure() {
    if (timeSignature == null) {
      return TicksEngine.TPQN * 4; // default 4/4
    }

    // Ticks per measure = TPQN * beats per measure * (4 / beatUnit)
    // Ej: 3/4 -> TPQN * 3 * (4/4) = 3 * TPQN
    //      6/8 -> TPQN * 6 * (4/8) = 3 * TPQN
    return (TicksEngine.TPQN * timeSignature!.numerator * 4) ~/
        timeSignature!.denominator;
  }

  double _computeHitLineX(double leftMargin) {
    return leftMargin + 180.0;
  }

  void _drawNotes(Canvas canvas, Size size, double hitLineX) {
    const double staffTop = compactStaffTop;

    if (visibleNotes.isEmpty) return;

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

    // Dibujar notas dentro de cada compás
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

    // Dibujar barras de agrupación (beams) entre notas conectadas
    _drawBeams(canvas, beamedGroups, baseTick, pxPerTick, hitLineX, staffTop);

    // Dibujar líneas de compás entre compases: punto medio entre
    // la última nota del compás actual y la primera del siguiente.
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

  /// Agrupa notas que están conectadas por barras (beams)
  List<List<NoteModel>> _groupBeamedNotes(List<NoteModel> notes) {
    final groups = <List<NoteModel>>[];
    List<NoteModel>? currentGroup;

    for (final note in notes) {
      if (note.isRest) continue; // Los silencios no se agrupan

      if (note.beamType == BeamType.begin) {
        // Iniciar nuevo grupo
        currentGroup = [note];
        groups.add(currentGroup);
      } else if (note.beamType == BeamType.continuation || note.beamType == BeamType.end) {
        // Continuar grupo existente
        if (currentGroup != null) {
          currentGroup.add(note);
        } else {
          // Si no hay grupo, crear uno nuevo (caso edge)
          currentGroup = [note];
          groups.add(currentGroup);
        }
      } else {
        // BeamType.none - no agrupar
        currentGroup = null;
      }

      if (note.beamType == BeamType.end) {
        currentGroup = null;
      }
    }

    return groups;
  }

  /// Dibuja las barras de agrupación entre notas conectadas
  void _drawBeams(
    Canvas canvas,
    List<List<NoteModel>> beamedGroups,
    int baseTick,
    double pxPerTick,
    double hitLineX,
    double staffTop,
  ) {
    for (final group in beamedGroups) {
      if (group.length < 2) continue; // Necesitamos al menos 2 notas para una barra

      final noteOffsets = <Offset>[];
      final notePositions = <int>[];

      for (final note in group) {
        final noteX = hitLineX + ((note.absoluteTick - baseTick) * pxPerTick);
        final position =
            nv.NoteVisual.notePositions[nv.NoteVisual.basePitchKey(note.pitch)] ?? 5;
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

      final stemPaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final beamPaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = beamThickness
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;

      final maxBeamLevel = group
          .map(_maxBeamLevelForNote)
          .fold<int>(1, (currentMax, value) => value > currentMax ? value : currentMax);
      final invertSecondaryBeamOffset = _shouldInvertSecondaryBeamOffset(group);
      final dottedEighthSixteenthPattern = _isDottedEighthSixteenthPattern(group);
      final normalizeStemLengthToPrimaryBeam =
          _isEighthTwoSixteenthsPattern(group) || dottedEighthSixteenthPattern;

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

      canvas.drawLine(
        Offset(firstStemX, naturalFirstBeamY),
        Offset(lastStemX, clampedLastBeamY),
        beamPaint,
      );

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
            // En grupos [corchea con punto, semicorchea] y [semicorchea, corchea con punto],
            // el hook de semicorchea debe apuntar hacia el interior del grupo.
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
    if (_isEighthTwoSixteenthsPattern(group)) {
      return true;
    }
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

  void _drawHitLine(Canvas canvas, Size size, double hitLineX) {
    const double staffTop = compactStaffTop;

    // Línea roja para marcar el beat
    canvas.drawLine(
      Offset(hitLineX, staffTop),
      Offset(hitLineX, staffTop + 4 * sr.StaffRenderer.SPACE_HEIGHT),
      Paint()
        ..color = Colors.red.withOpacity(0.8)
        ..strokeWidth = 3.0,
    );

    // Etiqueta "BEAT"
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

  @override
  bool shouldRepaint(SMuFLRenderer oldDelegate) {
    return true; // Redibujar en cada frame
  }
}
