import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import '../core/musical_engine/pitch_utils.dart';
import 'audio_service_lifecycle.dart';
import 'instrument_audio_output.dart';
import 'instrument_sample_generator.dart';
import 'instrument_type.dart';
import 'metronome_audio_output.dart';
import 'metronome_click_generator.dart';

abstract class SampledInstrumentAudioService
    implements InstrumentAudioOutput, MetronomeAudioOutput {
  SampledInstrumentAudioService({
    required InstrumentType instrument,
    required List<String> supportedNotes,
  }) : _instrument = instrument,
       _supportedNotes = List.unmodifiable(supportedNotes);

  final InstrumentType _instrument;
  final List<String> _supportedNotes;
  final AudioServiceLifecycle _lifecycle = AudioServiceLifecycle();
  final Map<String, AudioSource> _noteSources = {};
  SoLoud? _soloud;
  AudioSource? _accentClickSource;
  AudioSource? _normalClickSource;

  @override
  AudioServiceState get state => _lifecycle.state;

  @override
  Future<void> initialize() {
    return _lifecycle.initialize(_initializeResources);
  }

  Future<bool> _initializeResources() async {
    try {
      final soloud = SoLoud.instance;
      _soloud = soloud;
      await soloud.init();

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final cacheDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}'
        '${_instrument.name}_audio_cache',
      );
      if (!await cacheDirectory.exists()) {
        await cacheDirectory.create(recursive: true);
      }

      final missingNotes = <String>[];
      for (final note in _supportedNotes) {
        final sampleFile = _sampleFile(cacheDirectory, note);
        if (!await sampleFile.exists()) missingNotes.add(note);
      }

      if (missingNotes.isNotEmpty) {
        final samples = await generateInstrumentSampleBatch(
          _instrument,
          missingNotes,
        );
        for (final entry in samples.entries) {
          await _sampleFile(
            cacheDirectory,
            entry.key,
          ).writeAsBytes(entry.value, flush: true);
        }
      }

      final accentClickFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'metronome_accent.wav',
      );
      final normalClickFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'metronome_normal.wav',
      );
      if (!await accentClickFile.exists()) {
        await accentClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: true),
          flush: true,
        );
      }
      if (!await normalClickFile.exists()) {
        await normalClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: false),
          flush: true,
        );
      }

      for (final note in _supportedNotes) {
        _noteSources[note] = await soloud.loadFile(
          _sampleFile(cacheDirectory, note).path,
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

  File _sampleFile(Directory directory, String note) {
    return File('${directory.path}${Platform.pathSeparator}$note.wav');
  }

  @override
  Future<void> playNote(String pitch, {double volume = 0.85}) async {
    if (state == AudioServiceState.idle) await initialize();
    if (state != AudioServiceState.ready) return;

    final canonicalPitch = PitchUtils.normalize(pitch);
    final source = _noteSources[canonicalPitch];
    final soloud = _soloud;
    if (source == null || soloud == null) {
      debugPrint('No hay sample de ${_instrument.displayName} para $pitch');
      return;
    }
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {
    if (state == AudioServiceState.idle) await initialize();
    if (state != AudioServiceState.ready) return;

    final source = isAccent ? _accentClickSource : _normalClickSource;
    final soloud = _soloud;
    if (source == null || soloud == null) return;
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() => _lifecycle.dispose(_disposeResources);

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
}
