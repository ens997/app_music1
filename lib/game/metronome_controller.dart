import '../core/core.dart';

/// Controlador del metrónomo
class MetronomeController {
  // TODO: Síntesis de audio para metrónomo
  // TODO: Sistema de anacrusa automático
  // TODO: Acentos en primer beat del compás
  // TODO: Control de volumen

  final TicksEngine ticksEngine;
  final TimeSignature timeSignature;
  
  bool _isEnabled = false;
  double _volume = 0.5;
  int _currentBeat = 1;

  MetronomeController({
    required this.ticksEngine,
    required this.timeSignature,
  });

  bool get isEnabled => _isEnabled;
  double get volume => _volume;
  int get currentBeat => _currentBeat;

  /// Inicia el metrónomo
  void start() {
    _isEnabled = true;
    // TODO: Reproducir sonido inicial
    // TODO: Iniciar timing de beats
  }

  /// Detiene el metrónomo
  void stop() {
    _isEnabled = false;
  }

  /// Establece el volumen (0.0 - 1.0)
  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
  }

  /// Reproduce sonido de metrónomo
  void playMetronomeSound(bool isAccent) {
    // TODO: Síntesis de audio
    // Acepto: 880 Hz (9va arriba de A4)
    // Normal: 660 Hz (E5)
  }

  /// Actualiza el beat actual basado en el TicksEngine
  void update() {
    if (!_isEnabled) return;
    
    final ticksPerBeat = 480; // TPQN
    _currentBeat = (ticksEngine.currentTick ~/ ticksPerBeat) % timeSignature.numerator + 1;
  }
}
