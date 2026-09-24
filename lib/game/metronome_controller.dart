import 'dart:async';

import '../core/core.dart';
import '../audio/piano_audio_service.dart';

/// Controlador del metrónomo con soporte para múltiples métricas
/// Lee la métrica del MusicXML y genera acentos según la estructura musical
class MetronomeController {
  final TicksEngine ticksEngine;
  final TimeSignature timeSignature;
  final PianoAudioService audioService;

  bool _isEnabled = false;
  double _volume = 0.5;
  int _currentBeat = 0; // 0-based (0 es beat 1)
  int? _lastBeatIndex;

  // Volúmenes del metrónomo (para clicks de percusión pura)
  double _accentVolume = 0.0;
  double _normalVolume = 0.0;

  MetronomeController({
    required this.ticksEngine,
    required this.timeSignature,
    required this.audioService,
  }) {
    _configureNotesForTimeSignature();
  }

  bool get isEnabled => _isEnabled;
  double get volume => _volume;
  int get currentBeat => _currentBeat + 1; // Retorna 1-based para UI

  /// Configura los volúmenes del metrónomo según el tipo de beat
  /// Los clicks de percusión se generan sintéticamente sin contenido tonal
  void _configureNotesForTimeSignature() {
    // Volúmenes: acento más fuerte para distinguir beats principales
    _accentVolume = 0.85 * _volume;
    _normalVolume = 0.55 * _volume;
  }

  /// Inicia el metrónomo
  void start() {
    _isEnabled = true;
    _lastBeatIndex = null;
    // El primer sonido se reproducirá en el próximo update()
  }

  /// Detiene el metrónomo
  void stop() {
    _isEnabled = false;
  }

  /// Establece el volumen (0.0 - 1.0)
  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    // Recalcular volúmenes relativos
    _accentVolume = 0.85 * _volume;
    _normalVolume = 0.55 * _volume;
  }

  /// Calcula los ticks por beat según la métrica y BPM
  int _getTicksPerBeat() {
    // El beat se define por el denominador
    // En 4/4 y 2/4: beat = quarter note (480 ticks)
    // En 3/4: beat = quarter note (480 ticks)
    // En 6/8: beat = dotted quarter (720 ticks)

    const tpqn = 480; // Ticks per Quarter Note

    switch (timeSignature.denominator) {
      case 8:
        // 6/8, 9/8: dotted quarter note como beat
        return (tpqn * 1.5).toInt(); // 720 ticks
      case 4:
      default:
        // 2/4, 3/4, 4/4: quarter note como beat
        return tpqn;
    }
  }

  /// Determina si un beat es acento en esta métrica
  /// Depende de la métrica (2/4, 3/4, 4/4, 6/8)
  bool _isAccentBeat(int beatIndex) {
    // beatIndex es 0-based
    switch ('${timeSignature.numerator}/${timeSignature.denominator}') {
      case '2/4':
        // Acentos en beat 1 (posición 0)
        return beatIndex == 0;

      case '3/4': // Vals
        // Acentos en beat 1 (posición 0)
        return beatIndex == 0;

      case '4/4': // Compás común
        // Acentos en beats 1 y 3 (posiciones 0 y 2)
        return beatIndex == 0 || beatIndex == 2;

      case '6/8':
        // Dos acentos principales en 6/8: beats 1 y 4
        // (estructura: acento-débil-débil-acento-débil-débil)
        return beatIndex == 0 || beatIndex == 3;

      default:
        // Por defecto: acento solo en beat 1
        return beatIndex == 0;
    }
  }

  /// Reproduce el sonido del metrónomo (click de percusión suave)
  Future<void> _playMetronomeSound(bool isAccent) async {
    if (_volume <= 0) return; // No reproducir si volumen es 0

    final vol = (isAccent ? _accentVolume : _normalVolume).clamp(0.0, 1.0);

    try {
      await audioService.playMetronomeClick(isAccent: isAccent, volume: vol);
    } catch (e) {
      // Silenciar errores de audio sin afectar el juego
    }
  }

  /// Actualiza el estado del metrónomo basado en el tick actual
  /// Se debe llamar en cada frame del game loop
  Future<void> update() async {
    if (!_isEnabled) return;

    final ticksPerBeat = _getTicksPerBeat();
    final currentTick = ticksEngine.currentTick;

    final currentBeatIndex = currentTick ~/ ticksPerBeat;
    final firstBeatIndex = _lastBeatIndex == null ? 0 : _lastBeatIndex! + 1;

    for (
      var beatIndex = firstBeatIndex;
      beatIndex <= currentBeatIndex;
      beatIndex++
    ) {
      final beatInMeasure = beatIndex % timeSignature.numerator;
      _currentBeat = beatInMeasure;
      unawaited(_playMetronomeSound(_isAccentBeat(beatInMeasure)));
    }

    _lastBeatIndex = currentBeatIndex;
  }

  /// Obtiene información de debug sobre el estado actual del metrónomo
  String getDebugInfo() {
    return '''
MetronomeController Debug:
  Enabled: $_isEnabled
  Volume: ${(_volume * 100).toStringAsFixed(0)}%
  Current Beat: ${_currentBeat + 1}/${timeSignature.numerator}
  Time Signature: ${timeSignature.numerator}/${timeSignature.denominator}
  Ticks per Beat: ${_getTicksPerBeat()}
  Current Tick: ${ticksEngine.currentTick}
  Sound: Percussion clicks (no tonal content)
  Accent Volume: ${(_accentVolume * 100).toStringAsFixed(0)}%
  Normal Volume: ${(_normalVolume * 100).toStringAsFixed(0)}%
    ''';
  }

  /// Libera recursos
  void dispose() {
    _isEnabled = false;
  }
}
