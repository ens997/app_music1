import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../core/musical_engine/pitch_utils.dart';
import 'audio_service_lifecycle.dart';
import 'instrument_audio_output.dart';
import 'metronome_click_generator.dart';
import 'metronome_audio_output.dart';

/// Servicio de audio optimizado para piano.
/// - Genera ondas en Isolate (no bloquea UI).
/// - Cachea las ondas en disco para reutilización.
class PianoAudioService implements InstrumentAudioOutput, MetronomeAudioOutput {
  static const List<String> _supportedNotes = [
    'C4',
    'C#4',
    'D4',
    'D#4',
    'E4',
    'F4',
    'F#4',
    'G4',
    'G#4',
    'A4',
    'A#4',
    'B4',
    'C5',
    'C#5',
    'D5',
    'D#5',
    'E5',
    'F5',
    'F#5',
    'G5',
    'G#5',
    'A5',
    'A#5',
    'B5',
    'C6',
    'C#6',
    'D6',
    'D#6',
    'E6',
    'F6',
    'F#6',
    'G6',
    'G#6',
    'A6',
    'A#6',
    'B6',
  ];

  SoLoud? _soloud;
  final Map<String, AudioSource> _noteSources = {};
  AudioSource? _accentClickSource;
  AudioSource? _normalClickSource;
  final AudioServiceLifecycle _lifecycle = AudioServiceLifecycle();

  @override
  AudioServiceState get state => _lifecycle.state;

  /// Inicializa el servicio (generación asíncrona en Isolate).
  @override
  Future<void> initialize({bool forceRegenerate = false}) {
    return _lifecycle.initialize(
      () => _initializeResources(forceRegenerate: forceRegenerate),
    );
  }

  Future<bool> _initializeResources({required bool forceRegenerate}) async {
    try {
      final soloud = SoLoud.instance;
      _soloud = soloud;
      await soloud.init();

      // Intentar cargar desde caché de disco
      final cacheDir = await getApplicationDocumentsDirectory();
      final cacheFolder = Directory('${cacheDir.path}/piano_audio_cache');
      if (!await cacheFolder.exists()) {
        await cacheFolder.create(recursive: true);
      }

      // Cargar notas desde caché o generarlas
      final notesToGenerate = <String>[];
      for (final note in _supportedNotes) {
        final file = File('${cacheFolder.path}/$note.wav');
        if (!await file.exists() || forceRegenerate) {
          notesToGenerate.add(note);
        }
      }

      // Generar notas faltantes en Isolate
      if (notesToGenerate.isNotEmpty) {
        final generatedBytes = await compute(
          _generateWavesInBackground,
          notesToGenerate,
        );
        for (final entry in generatedBytes.entries) {
          final note = entry.key;
          final bytes = entry.value;

          // Guardar en disco para futuras ejecuciones
          final file = File('${cacheFolder.path}/$note.wav');
          await file.writeAsBytes(bytes);
        }
      }

      final accentClickFile = File('${cacheFolder.path}/metronome_accent.wav');
      final normalClickFile = File('${cacheFolder.path}/metronome_normal.wav');
      if (!await accentClickFile.exists() || forceRegenerate) {
        await accentClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: true),
        );
      }
      if (!await normalClickFile.exists() || forceRegenerate) {
        await normalClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: false),
        );
      }

      for (final note in _supportedNotes) {
        _noteSources[note] = await soloud.loadFile(
          '${cacheFolder.path}/$note.wav',
        );
      }
      _accentClickSource = await soloud.loadFile(accentClickFile.path);
      _normalClickSource = await soloud.loadFile(normalClickFile.path);

      return true;
    } on ArgumentError catch (error) {
      if (!error.message.toString().contains('flutter_soloud_plugin')) {
        await _disposeResources();
        rethrow;
      }
      debugPrint('El plugin de audio no está disponible: ${error.message}');
      _soloud = null;
      return false;
    } catch (_) {
      await _disposeResources();
      rethrow;
    }
  }

  /// Reproduce un click de metrónomo (percusión suave).
  /// isAccent: true para click de acento (más fuerte), false para click normal.
  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {
    if (state == AudioServiceState.idle) {
      await initialize();
    }

    if (state != AudioServiceState.ready) return;
    final source = isAccent ? _accentClickSource : _normalClickSource;
    final soloud = _soloud;
    if (source == null || soloud == null) return;
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  /// Reproduce una nota (pool de reproductores).
  @override
  Future<void> playNote(String note, {double volume = 0.85}) async {
    if (state == AudioServiceState.idle) {
      await initialize();
    }
    if (state != AudioServiceState.ready) return;
    final canonicalNote = PitchUtils.normalize(note);
    final source = _noteSources[canonicalNote];
    final soloud = _soloud;
    if (source == null || soloud == null) return;
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  /// Libera recursos.
  @override
  Future<void> dispose() {
    return _lifecycle.dispose(_disposeResources);
  }

  Future<void> _disposeResources() async {
    final soloud = _soloud;
    if (soloud != null) {
      for (final source in _noteSources.values) {
        await soloud.disposeSource(source);
      }
      if (_accentClickSource != null) {
        await soloud.disposeSource(_accentClickSource!);
      }
      if (_normalClickSource != null) {
        await soloud.disposeSource(_normalClickSource!);
      }
      soloud.deinit();
    }
    _noteSources.clear();
    _accentClickSource = null;
    _normalClickSource = null;
    _soloud = null;
  }

  /// Limpia la caché de disco (para forzar regeneración).
  static Future<void> clearCache() async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final cacheFolder = Directory('${cacheDir.path}/piano_audio_cache');
    if (await cacheFolder.exists()) {
      await cacheFolder.delete(recursive: true);
    }
  }
}

// ============================================================
// FUNCIONES TOP-LEVEL PARA ISOLATE
// ============================================================

/// Genera un mapa de notas -> bytes WAV en un Isolate.
/// Recibe una lista de nombres de notas y retorna sus bytes WAV por nota.
Future<Map<String, Uint8List>> _generateWavesInBackground(
  List<String> notes,
) async {
  final result = <String, Uint8List>{};
  for (final note in notes) {
    final frequency = _noteToFrequency(note);
    final durationMs = _durationForNote(note);
    final bytes = _buildSineWaveWav(
      note: note,
      frequencyHz: frequency,
      durationMs: durationMs,
    );
    result[note] = bytes;
  }
  return result;
}

// ============================================================
// FUNCIONES DE GENERACIÓN DE ONDA (PURO CÁLCULO, SIN DEPENDENCIAS DE FLUTTER)
// ============================================================

double _noteToFrequency(String note) {
  return PitchUtils.toFrequency(note) ?? 440.0;
}

int _durationForNote(String note) {
  final match = RegExp(r'\d$').firstMatch(note);
  final octave = int.tryParse(match?.group(0) ?? '5') ?? 5;

  switch (octave) {
    case 4:
      return 900;
    case 5:
      return 720;
    case 6:
      return 560;
    default:
      return 680;
  }
}

Uint8List _buildSineWaveWav({
  required String note,
  required double frequencyHz,
  required int durationMs,
  int sampleRate = 44100,
}) {
  final totalSamples = (sampleRate * durationMs / 1000).round();
  final byteRate = sampleRate * 2;
  final dataSize = totalSamples * 2;
  final buffer = ByteData(44 + dataSize);

  void writeString(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      buffer.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  final twoPiF = 2.0 * math.pi * frequencyHz;
  final octave =
      int.tryParse(RegExp(r'\d$').firstMatch(note)?.group(0) ?? '5') ?? 5;
  final attackSamples = (sampleRate * 0.0035).round();
  final decaySamples = (sampleRate * (octave <= 4 ? 0.16 : 0.11)).round();
  final releaseSamples = (sampleRate * (octave <= 4 ? 0.22 : 0.14)).round();
  final sustainLevel = octave <= 4 ? 0.22 : 0.16;
  final fundamentalDecay = octave <= 4 ? 2.8 : 3.6;
  final overtoneDecay = octave <= 4 ? 5.2 : 6.8;
  final phase2 = 0.31;
  final phase3 = 1.07;
  final phase4 = 2.21;

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final env = _envelopeForSample(
      sampleIndex: i,
      totalSamples: totalSamples,
      attackSamples: attackSamples,
      decaySamples: decaySamples,
      releaseSamples: releaseSamples,
      sustainLevel: sustainLevel,
    );

    final fundamental = math.sin(twoPiF * t) * math.exp(-fundamentalDecay * t);
    final second =
        math.sin((twoPiF * 2.0 * t) + phase2) * math.exp(-overtoneDecay * t);
    final third =
        math.sin((twoPiF * 3.0 * t) + phase3) *
        math.exp(-(overtoneDecay + 1.2) * t);
    final fourth =
        math.sin((twoPiF * 4.0 * t) + phase4) *
        math.exp(-(overtoneDecay + 2.1) * t);
    final detune =
        math.sin((twoPiF * 1.003 * t) + 0.17) *
        math.exp(-(fundamentalDecay + 0.9) * t);
    final hammerNoise =
        (math.sin(2.0 * math.pi * 6400 * t) +
            math.sin(2.0 * math.pi * 5100 * t)) *
        math.exp(-38 * t);

    final sample =
        ((fundamental * 0.72) +
            (second * 0.18) +
            (third * 0.08) +
            (fourth * 0.04) +
            (detune * 0.06) +
            (hammerNoise * 0.018)) *
        env *
        0.62;
    final intSample = (sample * 32767).round().clamp(-32768, 32767);
    buffer.setInt16(44 + (i * 2), intSample, Endian.little);
  }

  return buffer.buffer.asUint8List();
}

double _envelopeForSample({
  required int sampleIndex,
  required int totalSamples,
  required int attackSamples,
  required int decaySamples,
  required int releaseSamples,
  required double sustainLevel,
}) {
  if (sampleIndex < attackSamples) {
    final attackProgress = sampleIndex / attackSamples;
    return math.pow(attackProgress, 0.6).toDouble();
  }

  final decayEnd = attackSamples + decaySamples;
  if (sampleIndex < decayEnd) {
    final decayProgress = (sampleIndex - attackSamples) / decaySamples;
    return 1.0 -
        ((1.0 - sustainLevel) * math.pow(decayProgress, 0.85).toDouble());
  }

  final releaseStart = totalSamples - releaseSamples;
  if (sampleIndex < releaseStart) {
    return sustainLevel;
  }

  final releaseProgress = (sampleIndex - releaseStart) / releaseSamples;
  return sustainLevel *
      (1.0 - math.pow(releaseProgress, 1.4).toDouble()).clamp(0.0, 1.0);
}
