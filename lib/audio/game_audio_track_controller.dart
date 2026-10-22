import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef GameAudioPlayerFactory = GameAudioPlayer Function();
typedef AudioContextSetter = Future<void> Function(AudioContext context);
typedef AssetExists = Future<bool> Function(String assetPath);
typedef FileExists = Future<bool> Function(String path);

abstract interface class GameAudioPlayer {
  Future<void> stop();

  Future<void> setReleaseMode(ReleaseMode releaseMode);

  Future<void> setVolume(double volume);

  Future<void> setSource(Source source);

  Future<void> play(Source source, {required double volume});

  Future<Duration?> getCurrentPosition();

  Future<void> dispose();
}

class _AudioPlayersGameAudioPlayer implements GameAudioPlayer {
  final AudioPlayer _player;

  _AudioPlayersGameAudioPlayer(this._player);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) {
    return _player.setReleaseMode(releaseMode);
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSource(Source source) => _player.setSource(source);

  @override
  Future<void> play(Source source, {required double volume}) {
    return _player.play(source, volume: volume);
  }

  @override
  Future<Duration?> getCurrentPosition() => _player.getCurrentPosition();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Reproduce una pista opcional asociada a un archivo MusicXML.
///
/// Este controlador es independiente del audio del piano y del metrónomo.
/// Si no encuentra una pista compatible, todas sus operaciones son no-op.
class GameAudioTrackController {
  static final AudioContext _trackAudioContext = AudioContext(
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.media,
    ),
  );

  static const List<String> _audioExtensions = [
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
  ];

  final GameAudioPlayer _player;
  final AudioContextSetter _setAudioContext;
  late final AssetExists _assetExists;
  final FileExists _fileExists;
  Future<Set<String>>? _assetPathsFuture;
  Source? _source;
  bool _isDisposed = false;
  int _operationId = 0;
  double _volume = 1.0;

  GameAudioTrackController({
    GameAudioPlayerFactory? playerFactory,
    AudioContextSetter? setAudioContext,
    AssetExists? assetExists,
    FileExists? fileExists,
  }) : _player =
           (playerFactory ??
           (() => _AudioPlayersGameAudioPlayer(AudioPlayer())))(),
       _setAudioContext = setAudioContext ?? AudioPlayer.global.setAudioContext,
       _fileExists = fileExists ?? ((path) => File(path).exists()) {
    _assetExists = assetExists ?? _assetExistsInManifest;
  }

  bool get hasTrack => _source != null;

  Future<Duration?> getCurrentPosition() async {
    if (_isDisposed || _source == null) return null;
    return _player.getCurrentPosition();
  }

  /// Busca un audio con el mismo nombre base que [musicXmlPath].
  ///
  /// [musicXmlPath] puede ser un asset (`assets/...` o `musicxml_preload/...`)
  /// o una ruta local. La ausencia del audio no se considera un error.
  Future<void> prepare(String musicXmlPath, {double volume = 1.0}) async {
    final operationId = ++_operationId;
    _source = null;
    _volume = volume.clamp(0.0, 1.0);

    if (_isDisposed) return;

    try {
      await _setAudioContext(_trackAudioContext);
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
    } catch (error) {
      _source = null;
      debugPrint('Error preparando pista acompañante: $error');
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
        if (!await _assetExists(candidate)) return null;
        final assetPath = candidate.startsWith('assets/')
            ? candidate.substring('assets/'.length)
            : candidate;
        return AssetSource(assetPath);
      } catch (_) {
        return null;
      }
    }

    return await _fileExists(candidate) ? DeviceFileSource(candidate) : null;
  }

  Future<bool> _assetExistsInManifest(String assetPath) async {
    final assetPaths = await (_assetPathsFuture ??= _loadAssetManifest());
    return assetPaths.contains(assetPath);
  }

  Future<Set<String>> _loadAssetManifest() async {
    try {
      final data = await rootBundle.load('AssetManifest.bin');
      final decoded = const StandardMessageCodec().decodeMessage(data);
      if (decoded is Map) {
        return decoded.keys.map((key) => key.toString()).toSet();
      }
    } catch (_) {
      // SDKs antiguos pueden no incluir AssetManifest.bin.
    }

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifestJson);
      if (decoded is Map) {
        return decoded.keys.map((key) => key.toString()).toSet();
      }
    } catch (error) {
      debugPrint('Error leyendo manifiesto de assets de audio: $error');
    }

    return const <String>{};
  }
}
