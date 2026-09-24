import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reproduce una pista opcional asociada a un archivo MusicXML.
///
/// Este controlador es independiente del audio del piano y del metrónomo.
/// Si no encuentra una pista compatible, todas sus operaciones son no-op.
class GameAudioTrackController {
  static const List<String> _audioExtensions = [
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
  ];

  final AudioPlayer _player = AudioPlayer();
  Source? _source;
  bool _isDisposed = false;
  int _operationId = 0;
  double _volume = 1.0;

  bool get hasTrack => _source != null;

  /// Busca un audio con el mismo nombre base que [musicXmlPath].
  ///
  /// [musicXmlPath] puede ser un asset (`assets/...` o `musicxml_preload/...`)
  /// o una ruta local. La ausencia del audio no se considera un error.
  Future<void> prepare(String musicXmlPath, {double volume = 1.0}) async {
    final operationId = ++_operationId;
    _source = null;
    _volume = volume.clamp(0.0, 1.0);

    if (_isDisposed) return;

    await _player.stop();
    if (_isDisposed || operationId != _operationId) return;

    final candidates = _audioCandidates(musicXmlPath);
    for (final candidate in candidates) {
      final source = await _sourceIfAvailable(candidate, musicXmlPath);
      if (_isDisposed || operationId != _operationId) return;
      if (source == null) continue;

      _source = source;
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(_volume);
      await _player.setSource(source);
      return;
    }
  }

  /// Prepara un asset cuyo nombre se conoce, por ejemplo `001.musicxml`.
  /// Se utiliza para contenidos precargados sin ruta completa.
  Future<void> prepareFromAssetName(
    String fileName, {
    String directory = 'musicxml_preload',
    double volume = 1.0,
  }) {
    return prepare('$directory/$fileName', volume: volume);
  }

  /// Comienza la pista desde el inicio.
  ///
  /// La llamada se completa cuando la plataforma acepta la reproducción, por
  /// lo que sirve como barrera antes de iniciar el reloj visual del ejercicio.
  Future<void> playFromStart() async {
    if (_isDisposed || _source == null) return;
    try {
      await _player.stop();
      if (_isDisposed || _source == null) return;
      await _player.play(_source!, volume: _volume);
    } catch (error) {
      debugPrint('Error reproduciendo pista acompañante: $error');
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    ++_operationId;
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('Error deteniendo pista acompañante: $error');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    ++_operationId;
    _source = null;
    await _player.dispose();
  }

  List<String> _audioCandidates(String musicXmlPath) {
    final normalized = musicXmlPath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final directory = slash == -1 ? '' : normalized.substring(0, slash + 1);
    final fileName = slash == -1 ? normalized : normalized.substring(slash + 1);
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;

    return [
      for (final extension in _audioExtensions)
        '$directory$baseName.$extension',
    ];
  }

  Future<Source?> _sourceIfAvailable(
    String candidate,
    String originalMusicXmlPath,
  ) async {
    final isAsset =
        originalMusicXmlPath.startsWith('assets/') ||
        originalMusicXmlPath.startsWith('musicxml_preload/');

    if (isAsset) {
      try {
        await rootBundle.load(candidate);
        final assetPath = candidate.startsWith('assets/')
            ? candidate.substring('assets/'.length)
            : candidate;
        return AssetSource(assetPath);
      } catch (_) {
        return null;
      }
    }

    final file = File(candidate);
    return await file.exists() ? DeviceFileSource(candidate) : null;
  }
}
