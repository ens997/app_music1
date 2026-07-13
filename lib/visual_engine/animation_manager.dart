import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/core.dart';

/// Gestor centralizado de animaciones de feedback visual
class AnimationManager {
  final List<HitFeedbackAnimation> feedbackAnimations = [];
  final List<ComboAnimation> comboAnimations = [];
  final List<AccuracyAnimation> accuracyAnimations = [];

  void addHitFeedback(Offset position, HitQuality quality) {
    feedbackAnimations.add(
      HitFeedbackAnimation(
        position: position,
        quality: quality,
        startTime: DateTime.now(),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void addComboAnimation(Offset position, int combo) {
    if (combo >= 5) {
      comboAnimations.add(
        ComboAnimation(
          position: position,
          text: 'Combo x$combo',
          startTime: DateTime.now(),
          duration: const Duration(milliseconds: 1000),
        ),
      );
    }
  }

  void addAccuracyAnimation(
    Offset position,
    HitQuality quality,
    int deviationTicks,
  ) {
    accuracyAnimations.add(
      AccuracyAnimation(
        position: position,
        text: _getQualityText(quality, deviationTicks),
        quality: quality,
        startTime: DateTime.now(),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void updateAnimations() {
    final now = DateTime.now();
    feedbackAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });
    comboAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });
    accuracyAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });
  }

  void updateAndDraw(Canvas canvas, Size size) {
    final now = DateTime.now();

    feedbackAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;
      anim.draw(canvas);
      return false;
    });

    comboAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;
      anim.draw(canvas);
      return false;
    });

    accuracyAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;
      anim.draw(canvas);
      return false;
    });
  }

  void clearAll() {
    feedbackAnimations.clear();
    comboAnimations.clear();
    accuracyAnimations.clear();
  }

  String _getQualityText(HitQuality quality, int deviationTicks) {
    return '${quality.displayName} (${deviationTicks.abs()}ms)';
  }
}

// ============================================================
// CLASES DE ANIMACIÓN (con TextPainter cacheado)
// ============================================================

/// Animación de feedback de hit (radiante expandible)
class HitFeedbackAnimation {
  final Offset position;
  final HitQuality quality;
  final DateTime startTime;
  final Duration duration;
  late double maxRadius;
  late double currentRadius;
  late double opacity;

  // Pincel estático (se reutiliza)
  static final Paint _circlePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  HitFeedbackAnimation({
    required this.position,
    required this.quality,
    required this.startTime,
    required this.duration,
  }) {
    maxRadius = 60.0;
  }

  void update(DateTime now) {
    final elapsed = now.difference(startTime);
    final progress = (elapsed.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
    currentRadius = maxRadius * progress;
    opacity = 1.0 - progress;
  }

  bool isComplete() {
    return DateTime.now().difference(startTime) >= duration;
  }

  void draw(Canvas canvas) {
    final color = Color(quality.colorValue).withOpacity(opacity);
    _circlePaint.color = color;
    canvas.drawCircle(position, currentRadius, _circlePaint);

    // Puntos radiantes
    for (int i = 0; i < 8; i++) {
      final angle = (i * 2 * math.pi) / 8;
      final pointX = position.dx + math.cos(angle) * currentRadius;
      final pointY = position.dy + math.sin(angle) * currentRadius;
      canvas.drawCircle(
        Offset(pointX, pointY),
        2.0,
        _circlePaint..color = color,
      );
    }
  }
}

/// Animación de combo
class ComboAnimation {
  final Offset position;
  final String text;
  final DateTime startTime;
  final Duration duration;
  late double opacity;
  late double scaleTransform;
  late Offset yOffset;

  // TextPainter cacheado
  final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  ComboAnimation({
    required this.position,
    required this.text,
    required this.startTime,
    required this.duration,
  });

  void update(DateTime now) {
    final elapsed = now.difference(startTime);
    final progress = (elapsed.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
    opacity = 1.0 - progress;
    scaleTransform = 1.0 + progress * 0.3;
    yOffset = Offset(0, -progress * 50);
  }

  bool isComplete() {
    return DateTime.now().difference(startTime) >= duration;
  }

  void draw(Canvas canvas) {
    _painter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 28 * scaleTransform,
        fontWeight: FontWeight.bold,
        color: Colors.amber.withOpacity(opacity),
      ),
    );
    _painter.layout();
    final finalPos = Offset(
      position.dx + yOffset.dx - _painter.width / 2,
      position.dy + yOffset.dy - _painter.height / 2,
    );
    _painter.paint(canvas, finalPos);
  }
}

/// Animación de precisión del hit
class AccuracyAnimation {
  final Offset position;
  final String text;
  final HitQuality quality;
  final DateTime startTime;
  final Duration duration;
  late double opacity;
  late double yOffset;

  // TextPainter cacheado
  final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  AccuracyAnimation({
    required this.position,
    required this.text,
    required this.quality,
    required this.startTime,
    required this.duration,
  });

  void update(DateTime now) {
    final elapsed = now.difference(startTime);
    final progress = (elapsed.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);
    opacity = 1.0 - progress;
    yOffset = -progress * 40;
  }

  bool isComplete() {
    return DateTime.now().difference(startTime) >= duration;
  }

  void draw(Canvas canvas) {
    _painter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(quality.colorValue).withOpacity(opacity),
      ),
    );
    _painter.layout();
    final finalPos = Offset(
      position.dx - _painter.width / 2,
      position.dy + yOffset,
    );
    _painter.paint(canvas, finalPos);
  }
}