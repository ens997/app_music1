import 'package:flutter/material.dart';
import '../core/core.dart';

/// Nivel de acierto simplificado para el feedback visual de las notas.
/// Perfecto: verde, buena (great/good): amarillo, mala (miss o tono
/// incorrecto): rojo.
enum FeedbackTier {
  perfect,
  good,
  miss;

  static FeedbackTier fromHit(HitQuality quality, bool isCorrectPitch) {
    if (!isCorrectPitch || quality == HitQuality.miss) return FeedbackTier.miss;
    if (quality == HitQuality.perfect) return FeedbackTier.perfect;
    return FeedbackTier.good;
  }

  Color get color {
    switch (this) {
      case FeedbackTier.perfect:
        return const Color(0xFF4CAF50); // Verde
      case FeedbackTier.good:
        return const Color(0xFFFFC107); // Amarillo
      case FeedbackTier.miss:
        return const Color(0xFFE94560); // Rojo
    }
  }
}

/// Gestor centralizado de animaciones de feedback visual
class AnimationManager {
  // Límite defensivo: evita crecimiento sin control si el usuario acierta
  // notas más rápido de lo que las animaciones tardan en desvanecerse.
  static const int _maxConcurrentFeedback = 8;

  final List<HitFeedbackAnimation> feedbackAnimations = [];

  void addHitFeedback(Offset position, FeedbackTier tier) {
    if (feedbackAnimations.length >= _maxConcurrentFeedback) {
      feedbackAnimations.removeAt(0);
    }
    feedbackAnimations.add(
      HitFeedbackAnimation(
        position: position,
        tier: tier,
        startTime: DateTime.now(),
      ),
    );
  }

  void updateAndDraw(Canvas canvas, Size size) {
    final now = DateTime.now();
    feedbackAnimations.removeWhere((anim) {
      anim.update(now);
      if (anim.isComplete(now)) return true;
      anim.draw(canvas);
      return false;
    });
  }

  void clearAll() {
    feedbackAnimations.clear();
  }
}

// ============================================================
// ANIMACIÓN DE FEEDBACK (pulso minimalista de un solo color)
// ============================================================

/// Pulso breve y minimalista en el punto de impacto de la nota.
/// Un único círculo relleno que crece y se desvanece; sin texto ni
/// trazos múltiples, para mantener el costo de dibujo al mínimo.
class HitFeedbackAnimation {
  final Offset position;
  final FeedbackTier tier;
  final DateTime startTime;
  static const Duration _duration = Duration(milliseconds: 260);
  static const double _maxRadius = 22.0;

  double _radius = 0.0;
  double _opacity = 1.0;

  // Pincel estático reutilizado entre instancias (sin allocations por frame).
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  HitFeedbackAnimation({
    required this.position,
    required this.tier,
    required this.startTime,
  });

  void update(DateTime now) {
    final elapsed = now.difference(startTime).inMilliseconds;
    final progress = (elapsed / _duration.inMilliseconds).clamp(0.0, 1.0);
    // Crecimiento rápido (ease-out) seguido de desvanecimiento lineal.
    _radius = _maxRadius * (1 - (1 - progress) * (1 - progress));
    _opacity = 1.0 - progress;
  }

  bool isComplete(DateTime now) {
    return now.difference(startTime) >= _duration;
  }

  void draw(Canvas canvas) {
    _fillPaint.color = tier.color.withOpacity(_opacity * 0.55);
    canvas.drawCircle(position, _radius, _fillPaint);
  }
}
