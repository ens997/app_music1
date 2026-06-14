import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/core.dart';

/// Gestor centralizado de animaciones de feedback visual
class AnimationManager {
  final List<HitFeedbackAnimation> feedbackAnimations = [];
  final List<ComboAnimation> comboAnimations = [];
  final List<AccuracyAnimation> accuracyAnimations = [];

  /// Agrega una animación de feedback de hit
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

  /// Agrega una animación de combo
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

  /// Agrega una animación de precisión
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

  /// Actualiza todas las animaciones (sin dibujar)
  void updateAnimations() {
    final now = DateTime.now();

    // Actualizar feedback animations
    feedbackAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });

    // Actualizar combo animations
    comboAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });

    // Actualizar accuracy animations
    accuracyAnimations.removeWhere((anim) {
      anim.update(now);
      return anim.isComplete();
    });
  }

  /// Actualiza y dibuja todas las animaciones
  void updateAndDraw(Canvas canvas, Size size) {
    final now = DateTime.now();

    // Actualizar feedback animations
    feedbackAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;

      anim.draw(canvas);
      return false;
    });

    // Actualizar combo animations
    comboAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;

      anim.draw(canvas);
      return false;
    });

    // Actualizar accuracy animations
    accuracyAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete()) return true;

      anim.draw(canvas);
      return false;
    });
  }

  /// Limpia todas las animaciones
  void clearAll() {
    feedbackAnimations.clear();
    comboAnimations.clear();
    accuracyAnimations.clear();
  }

  String _getQualityText(HitQuality quality, int deviationTicks) {
    return '${quality.displayName} (${deviationTicks.abs()}ms)';
  }
}

/// Animación de feedback de hit (radiante expandible)
class HitFeedbackAnimation {
  final Offset position;
  final HitQuality quality;
  final DateTime startTime;
  final Duration duration;

  late double maxRadius;
  late double currentRadius;
  late double opacity;

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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Color(quality.colorValue).withOpacity(opacity);

    canvas.drawCircle(position, currentRadius, paint);

    // Dibujar puntos de radiante
    for (int i = 0; i < 8; i++) {
      final angle = (i * 2 * math.pi) / 8;
      final pointX = position.dx + math.cos(angle) * currentRadius;
      final pointY = position.dy + math.sin(angle) * currentRadius;

      canvas.drawCircle(
        Offset(pointX, pointY),
        2.0,
        Paint()..color = Color(quality.colorValue).withOpacity(opacity),
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
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 28 * scaleTransform,
          fontWeight: FontWeight.bold,
          color: Colors.amber.withOpacity(opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final finalPos = Offset(
      position.dx + yOffset.dx - textPainter.width / 2,
      position.dy + yOffset.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, finalPos);
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
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(quality.colorValue).withOpacity(opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final finalPos = Offset(
      position.dx - textPainter.width / 2,
      position.dy + yOffset,
    );

    textPainter.paint(canvas, finalPos);
  }
}
