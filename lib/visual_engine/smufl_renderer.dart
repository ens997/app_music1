import 'note_visual.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import 'staff_renderer.dart' as sr;
import 'note_visual.dart' as nv;
import 'animation_manager.dart' as am;
import 'note_layout.dart';

/// Renderizador visual principal usando Canvas
/// Versión OPTIMIZADA para móvil:
/// - Cache del pentagrama en Picture
/// - Pinceles estáticos (sin creación en paint)
/// - Dibujo eficiente de notas usando posiciones precalculadas
/// - Culling: solo dibuja notas visibles en el viewport
class SMuFLRenderer extends CustomPainter {
  static const double compactStaffTop = 43;
  static const double _cullingMargin = 96;

  final TicksEngine? ticksEngine;
  final TimeSignature? timeSignature;
  final KeySignature? keySignature;
  final List<NoteLayout> noteLayouts;
  final am.AnimationManager animationManager;
  final ClefType clefType;
  final bool showTimeSignature;
  final bool showKeySignature;
  final bool showBarLines;
  final bool showHitLine;
  final bool showStaff;
  final bool showNotes;
  final bool showBeams;
  final double? hitLineXOverride;

  // Nuevos parámetros para culling
  final double? scrollOffset;
  final double? viewportWidth;

  final Color backgroundColor;
  final Color staffColor;
  final Color noteColor;

  // Cache del pentagrama
  ui.Picture? _cachedStaffPicture;
  Size? _lastCacheSize;
  late final List<double> _barLineXPositions;
  late final List<List<NoteLayout>> _beamGroups;

  // Pinceles estáticos
  static final Paint _backgroundPaint = Paint();
  static final Paint _hitLinePaint = Paint()
    ..color = Colors.red.withOpacity(0.8)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  // TextPainter estático para etiqueta "BEAT"
  static final TextPainter _beatLabelPainter = TextPainter(
    text: const TextSpan(
      text: 'BEAT',
      style: TextStyle(
        color: Colors.red,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  SMuFLRenderer({
    this.ticksEngine,
    this.timeSignature,
    this.keySignature,
    required this.noteLayouts,
    required this.animationManager,
    this.clefType = ClefType.treble,
    this.showTimeSignature = true,
    this.showKeySignature = true,
    this.showBarLines = true,
    this.showHitLine = true,
    this.showStaff = true,
    this.showNotes = true,
    this.showBeams = true,
    this.hitLineXOverride,
    this.scrollOffset,
    this.viewportWidth,
    ValueListenable<double>? scrollOffsetListenable,
    Listenable? repaint,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.staffColor = Colors.black87,
    this.noteColor = Colors.black,
  })  : scrollOffsetListenable = scrollOffsetListenable,
        super(repaint: repaint) {
    _barLineXPositions = _calculateBarLineXPositions();
    _beamGroups = _groupBeamedNotes(noteLayouts);
  }

  final ValueListenable<double>? scrollOffsetListenable;

  // ============================================================
  // CONSTRUCCIÓN DEL CACHE DEL PENTAGRAMA
  // ============================================================

  void _buildStaffCache(Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _backgroundPaint..color = backgroundColor,
    );

    // Pentagrama, clave y compás
    _drawStaffWithElements(canvas, size);

    _cachedStaffPicture = recorder.endRecording();
    _lastCacheSize = size;
  }

  // ============================================================
  // MÉTODO PAINT (optimizado)
  // ============================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // Dibujar cache del pentagrama solo en la capa estática.
    if (showStaff) {
      if (_cachedStaffPicture == null || _lastCacheSize != size) {
        _buildStaffCache(size);
      }
      canvas.drawPicture(_cachedStaffPicture!);
    }

    // Dibujar notas (usando posiciones precalculadas + culling)
    if (showNotes) _drawNotes(canvas, size);

    // Dibujar beams (usando posiciones precalculadas + culling)
    if (showBeams) _drawBeams(canvas);

    if (showBarLines && !showNotes && noteLayouts.isNotEmpty) {
      _drawBarLines(canvas);
    }

    // Línea de beat (si está activa)
    if (showHitLine && hitLineXOverride != null) {
      _drawHitLine(canvas, hitLineXOverride!);
    }

    // Animaciones
    animationManager.updateAndDraw(canvas, size);
  }

  // ============================================================
  // DIBUJO DEL PENTAGRAMA (solo para el cache)
  // ============================================================

  void _drawStaffWithElements(Canvas canvas, Size size) {
    const double topMargin = compactStaffTop;
    const double leftMargin = 80;
    const double rightMargin = 40;

    // Pentagrama (5 líneas)
    final staffBounds = Rect.fromLTRB(
      leftMargin,
      topMargin,
      size.width - rightMargin,
      topMargin + 4 * sr.StaffRenderer.SPACE_HEIGHT,
    );
    sr.StaffRenderer.drawStaff(canvas, staffBounds, drawAdditionalLines: false);

    // Clave musical
    final clefCenterY = topMargin + 2 * sr.StaffRenderer.SPACE_HEIGHT;
    final clefCenterX = leftMargin + 30;
    sr.StaffRenderer.drawClef(canvas, Offset(clefCenterX, clefCenterY), clefType);

    // Armadura
    if (showKeySignature && keySignature != null) {
      final keySigStartX =
          sr.StaffRenderer.clefRightEdge(clefCenterX, clefType) +
          sr.StaffRenderer.CLEF_TO_KEY_SIGNATURE_GAP;
      sr.StaffRenderer.drawKeySignature(
        canvas,
        Offset(keySigStartX, topMargin),
        keySignature!,
        clefType,
      );
    }

    // Compás (time signature)
    if (showTimeSignature && timeSignature != null) {
      final keySigStartX =
          sr.StaffRenderer.clefRightEdge(clefCenterX, clefType) +
          sr.StaffRenderer.CLEF_TO_KEY_SIGNATURE_GAP;
      final maxKeyWidth = sr.StaffRenderer.maxKeySignatureLayoutWidth();
      final timeSigX = keySigStartX + maxKeyWidth + sr.StaffRenderer.KEY_SIGNATURE_TIME_GAP;
      sr.StaffRenderer.drawTimeSignature(
        canvas,
        Offset(timeSigX, clefCenterY - 22),
        timeSignature!,
      );
    }
  }

  // ============================================================
  // DIBUJO DE NOTAS (con culling)
  // ============================================================

  void _drawNotes(Canvas canvas, Size size) {
    if (noteLayouts.isEmpty) return;

    // Calcular rango visible si se proporcionan los parámetros
    double? startX, endX;
    final currentScrollOffset = scrollOffsetListenable?.value ?? scrollOffset;
    if (currentScrollOffset != null && viewportWidth != null) {
      startX = currentScrollOffset - _cullingMargin;
      endX = currentScrollOffset + viewportWidth! + _cullingMargin;
    }

    for (final layout in noteLayouts) {
      // Culling: saltar notas fuera del viewport
      if (startX != null && endX != null) {
        if (layout.position.dx < startX || layout.position.dx > endX) continue;
      }
      NoteVisual.drawNote(
        canvas,
        layout.note,
        layout.position,
        compactStaffTop,
        noteColor,
      );
    }

    if (showBarLines && noteLayouts.isNotEmpty) {
      _drawBarLines(canvas);
    }
  }

  // ============================================================
  // DIBUJO DE LÍNEAS DE COMPÁS
  // ============================================================

  void _drawBarLines(Canvas canvas) {
    for (final barX in _barLineXPositions) {
      sr.StaffRenderer.drawBarLine(
        canvas,
        Offset(barX, compactStaffTop),
        4 * sr.StaffRenderer.SPACE_HEIGHT,
      );
    }
  }

  // ============================================================
  // DIBUJO DE BEAMS (con culling)
  // ============================================================

  void _drawBeams(Canvas canvas) {
    final currentScrollOffset = scrollOffsetListenable?.value ?? scrollOffset;
    final groups = currentScrollOffset != null && viewportWidth != null
      ? _beamGroups
        .map((group) => group
          .where(
            (layout) =>
              layout.position.dx >= currentScrollOffset - _cullingMargin &&
              layout.position.dx <=
                currentScrollOffset + viewportWidth! + _cullingMargin,
          )
          .toList())
        .where((group) => group.isNotEmpty)
        .toList()
      : _beamGroups;
    if (groups.isEmpty) return;

    // Pinceles para stems y beams (estáticos)
    final stemPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final beamPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    for (final group in groups) {
      if (group.length < 2) continue;

      // Extraer offsets de las notas (posición de la cabeza)
      final noteOffsets = group.map((l) => l.position).toList();

      // Determinar dirección del stem (basado en posición media)
      final avgPosition = group
          .map((l) => _staffPositionForNote(l.note))
          .reduce((a, b) => a + b) / group.length;
      final stemUp = avgPosition >= 4;
      final stemDirection = stemUp ? -1.0 : 1.0;

      // Calcular posiciones de los stems (X fija, Y hasta el beam)
      const baseStemLength = 43.0;
      final firstPos = noteOffsets.first;
      final lastPos = noteOffsets.last;
      final firstStemX = firstPos.dx + (stemUp ? 8 : -8);
      final lastStemX = lastPos.dx + (stemUp ? 8 : -8);
      final naturalFirstBeamY = firstPos.dy + (stemDirection * baseStemLength);
      final naturalLastBeamY = lastPos.dy + (stemDirection * baseStemLength);
      final maxBeamDelta = 12.0;
      final clampedLastBeamY = naturalFirstBeamY +
          (naturalLastBeamY - naturalFirstBeamY).clamp(-maxBeamDelta, maxBeamDelta);

      // Dibujar stems individuales
      for (int i = 0; i < group.length; i++) {
        final offset = noteOffsets[i];
        final stemX = offset.dx + (stemUp ? 8 : -8);
        final noteLevel = _maxBeamLevelForNote(group[i].note);
        final stemEndY = _beamYAtX(
          stemX,
          firstStemX,
          naturalFirstBeamY,
          lastStemX,
          clampedLastBeamY,
          _beamLevelOffset(stemDirection, noteLevel),
        );
        canvas.drawLine(
          Offset(stemX, offset.dy),
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

      // Dibujar beams adicionales (si hay semicorcheas, etc.)
      final maxBeamLevel = group
          .map((l) => _maxBeamLevelForNote(l.note))
          .fold<int>(1, (max, v) => v > max ? v : max);

      for (int level = 2; level <= maxBeamLevel; level++) {
        final levelOffset = _beamLevelOffset(stemDirection, level);
        for (int i = 0; i < group.length - 1; i++) {
          if (!_hasContinuousBeamBetween(group[i].note, group[i + 1].note, level)) continue;
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

        // Hooks (ganchos) para notas sueltas en el nivel
        for (int i = 0; i < group.length; i++) {
          final note = group[i].note;
          final beamType = _effectiveBeamType(note, level);
          if (beamType == BeamType.none) continue;
          final hasLeft = i > 0 && _hasContinuousBeamBetween(group[i-1].note, note, level);
          final hasRight = i < group.length - 1 && _hasContinuousBeamBetween(note, group[i+1].note, level);
          if (hasLeft || hasRight) continue;

          final startX = noteOffsets[i].dx + (stemUp ? 8 : -8);
          final hookLength = 16.0;
          final endX = switch (beamType) {
            BeamType.backwardHook => startX - hookLength,
            BeamType.forwardHook => startX + hookLength,
            _ => (i == group.length - 1) ? startX - hookLength : startX + hookLength,
          };
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

  // ============================================================
  // MÉTODOS AUXILIARES PARA BEAMS
  // ============================================================

  List<List<NoteLayout>> _groupBeamedNotes(List<NoteLayout> layouts) {
    final groups = <List<NoteLayout>>[];
    List<NoteLayout>? currentGroup;

    for (final layout in layouts) {
      final note = layout.note;
      if (note.isRest) continue;

      if (note.beamType == BeamType.begin) {
        currentGroup = [layout];
        groups.add(currentGroup);
      } else if (note.beamType == BeamType.continuation || note.beamType == BeamType.end) {
        if (currentGroup != null) {
          currentGroup.add(layout);
        } else {
          currentGroup = [layout];
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

  int _staffPositionForNote(NoteModel note) {
    final key = nv.NoteVisual.basePitchKey(note.pitch);
    return nv.NoteVisual.notePositions[key] ?? 5;
  }

  int _maxBeamLevelForNote(NoteModel note) {
    var maxLevel = note.beamType.isBeamed ? 1 : 0;
    for (final entry in note.beamLevels.entries) {
      if (entry.value != BeamType.none && entry.key > maxLevel) {
        maxLevel = entry.key;
      }
    }
    if (maxLevel == 1 && note.duration == NoteDuration.sixteenth && note.beamType.isBeamed) {
      maxLevel = 2;
    }
    return maxLevel == 0 ? 1 : maxLevel;
  }

  BeamType _effectiveBeamType(NoteModel note, int level) {
    if (level == 1) return note.beamType;
    final beamType = note.beamLevels[level];
    if (beamType != null) return beamType;
    if (level == 2 && note.duration == NoteDuration.sixteenth && note.beamType.isBeamed) {
      return BeamType.continuation;
    }
    return BeamType.none;
  }

  bool _hasContinuousBeamBetween(NoteModel left, NoteModel right, int level) {
    final leftType = _effectiveBeamType(left, level);
    final rightType = _effectiveBeamType(right, level);
    final leftConnectsRight = leftType == BeamType.begin || leftType == BeamType.continuation;
    final rightConnectsLeft = rightType == BeamType.continuation || rightType == BeamType.end;
    return leftConnectsRight && rightConnectsLeft;
  }

  double _beamYAtX(double x, double startX, double startY, double endX, double endY, double levelOffset) {
    if ((endX - startX).abs() < 0.001) return startY + levelOffset;
    final t = (x - startX) / (endX - startX);
    return startY + ((endY - startY) * t) + levelOffset;
  }

  double _beamLevelOffset(double stemDirection, int level) {
    // El nivel secundario queda debajo del principal en la agrupación visual.
    return -stemDirection * 7.5 * (level - 1);
  }

  // ============================================================
  // DIBUJO DE LÍNEA DE BEAT
  // ============================================================

  void _drawHitLine(Canvas canvas, double hitLineX) {
    const double staffTop = compactStaffTop;
    canvas.drawLine(
      Offset(hitLineX, staffTop),
      Offset(hitLineX, staffTop + 4 * sr.StaffRenderer.SPACE_HEIGHT),
      _hitLinePaint,
    );
    // Etiqueta "BEAT"
    _beatLabelPainter.paint(
      canvas,
      Offset(hitLineX - _beatLabelPainter.width / 2, 40),
    );
  }

  // ============================================================
  // MÉTODOS AUXILIARES GENERALES
  // ============================================================

  int _ticksPerMeasure() {
    if (timeSignature == null) {
      return TicksEngine.tpnq * 4;
    }
    return (TicksEngine.tpnq * timeSignature!.numerator * 4) ~/ timeSignature!.denominator;
  }

  List<double> _calculateBarLineXPositions() {
    final ticksPerMeasure = _ticksPerMeasure();
    if (ticksPerMeasure <= 0 || noteLayouts.isEmpty) return [];

    final measureMap = <int, List<NoteLayout>>{};
    for (final layout in noteLayouts) {
      final measure = layout.note.absoluteTick ~/ ticksPerMeasure;
      measureMap.putIfAbsent(measure, () => []).add(layout);
    }

    final measures = measureMap.keys.toList()..sort();
    return [
      for (int i = 0; i < measures.length - 1; i++)
        (measureMap[measures[i]]!.last.position.dx +
                measureMap[measures[i + 1]]!.first.position.dx) /
            2.0,
    ];
  }

  // ============================================================
  // SHOULD REPAINT
  // ============================================================

  @override
  bool shouldRepaint(SMuFLRenderer oldDelegate) {
    // Si la lista de layouts cambia (nueva instancia), repintar
    if (oldDelegate.noteLayouts != noteLayouts) return true;
    // También por otros cambios
    return oldDelegate.timeSignature != timeSignature ||
        oldDelegate.keySignature != keySignature ||
        oldDelegate.clefType != clefType ||
        oldDelegate.showTimeSignature != showTimeSignature ||
        oldDelegate.showKeySignature != showKeySignature ||
        oldDelegate.showBarLines != showBarLines ||
        oldDelegate.showHitLine != showHitLine ||
        oldDelegate.showStaff != showStaff ||
        oldDelegate.showNotes != showNotes ||
        oldDelegate.showBeams != showBeams ||
        oldDelegate.hitLineXOverride != hitLineXOverride ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.staffColor != staffColor ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.animationManager != animationManager ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.scrollOffsetListenable != scrollOffsetListenable ||
        oldDelegate.viewportWidth != viewportWidth;
  }
}