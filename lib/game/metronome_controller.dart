import 'dart:async';

import '../core/core.dart';
import '../audio/metronome_audio_output.dart';

/// Controlador del metrónomo con soporte para múltiples métricas
/// Lee la métrica del MusicXML y genera acentos según la estructura musical
class MetronomeController {
  final TicksEngine ticksEngine;
  final TimeSignature timeSignature;
  final MetronomeAudioOutput audioService;

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
    // El metrónomo emite cada figura del denominador. En 6/8, los
    // acentos agrupan tres corcheas, pero los pulsos siguen siendo corcheas.

    const tpqn = 480; // Ticks per Quarter Note

    switch (timeSignature.denominator) {
      case 8:
        return tpqn ~/ 2;
      case 4:
      default:
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

      default:
        if (timeSignature.denominator == 8) {
          // Métricas compuestas: cada grupo de tres corcheas comienza
          // con un acento (1 y 4 en 6/8).
          return beatIndex % 3 == 0;
        }
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

  /// Actualiza el estado del metrónomo basado en el tick actual.
  /// Un frame tardío reproduce solo el beat vigente, nunca una ráfaga de beats
  /// ya vencidos.
  Future<void> update() {
    if (!_isEnabled) return Future.value();

    final ticksPerBeat = _getTicksPerBeat();
    final currentTick = ticksEngine.currentTick;

    final currentBeatIndex = currentTick ~/ ticksPerBeat;
    if (_lastBeatIndex == currentBeatIndex) return Future.value();

    _lastBeatIndex = currentBeatIndex;
    final beatInMeasure = currentBeatIndex % timeSignature.numerator;
    _currentBeat = beatInMeasure;
    return _playMetronomeSound(_isAccentBeat(beatInMeasure));
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
