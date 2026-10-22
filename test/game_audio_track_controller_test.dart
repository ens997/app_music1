import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/game_audio_track_controller.dart';

class _FakeAudioPlayer implements GameAudioPlayer {
  final List<String> calls = [];
  final List<Source> playedSources = [];
  Source? configuredSource;
  double? configuredVolume;
  Duration? currentPosition = const Duration(milliseconds: 250);
  bool disposed = false;
  bool failOnSetSource = false;

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    calls.add('setReleaseMode:$releaseMode');
  }

  @override
  Future<void> setVolume(double volume) async {
    configuredVolume = volume;
    calls.add('setVolume:$volume');
  }

  @override
  Future<void> setSource(Source source) async {
    if (failOnSetSource) throw StateError('source rejected');
    configuredSource = source;
    calls.add('setSource');
  }

  @override
  Future<void> play(Source source, {required double volume}) async {
    playedSources.add(source);
    calls.add('play:$volume');
  }

  @override
  Future<Duration?> getCurrentPosition() async => currentPosition;

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}

void main() {
  late _FakeAudioPlayer fakePlayer;
  late List<String> checkedAssets;
  late List<String> checkedFiles;
  late List<AudioContext> configuredContexts;

  GameAudioTrackController createController({
    AssetExists? assetExists,
    FileExists? fileExists,
    AudioContextSetter? setAudioContext,
  }) {
    fakePlayer = _FakeAudioPlayer();
    checkedAssets = [];
    checkedFiles = [];
    configuredContexts = [];

    return GameAudioTrackController(
      playerFactory: () => fakePlayer,
      setAudioContext:
          setAudioContext ??
          ((context) async => configuredContexts.add(context)),
      assetExists:
          assetExists ??
          ((path) async {
            checkedAssets.add(path);
            return false;
          }),
      fileExists:
          fileExists ??
          ((path) async {
            checkedFiles.add(path);
            return false;
          }),
    );
  }

  test('prepares the first available asset candidate', () async {
    final controller = createController(
      assetExists: (path) async {
        checkedAssets.add(path);
        return path.endsWith('/1.wav');
      },
    );

    await controller.prepare(
      'assets/exercises/inicial/1.musicxml',
      volume: 0.4,
    );

    expect(controller.hasTrack, isTrue);
    expect(checkedAssets, [
      'assets/exercises/inicial/1.mp3',
      'assets/exercises/inicial/1.wav',
    ]);
    expect(fakePlayer.configuredVolume, 0.4);
    expect(fakePlayer.configuredSource, isA<AssetSource>());
    expect(
      (fakePlayer.configuredSource! as AssetSource).path,
      'exercises/inicial/1.wav',
    );
    expect(configuredContexts, hasLength(1));
  });

  test('uses a local device file and tries extensions in order', () async {
    final controller = createController(
      fileExists: (path) async {
        checkedFiles.add(path);
        return path.endsWith('score.ogg');
      },
    );

    await controller.prepare(r'C:\scores\score.musicxml');

    expect(controller.hasTrack, isTrue);
    expect(checkedFiles, [
      r'C:/scores/score.mp3',
      r'C:/scores/score.wav',
      r'C:/scores/score.ogg',
    ]);
    expect(fakePlayer.configuredSource, isA<DeviceFileSource>());
    expect(
      (fakePlayer.configuredSource! as DeviceFileSource).path,
      r'C:/scores/score.ogg',
    );
  });

  test('does nothing when no compatible track exists', () async {
    final controller = createController(
      assetExists: (path) async {
        checkedAssets.add(path);
        return false;
      },
    );

    await controller.prepare('musicxml_preload/001.musicxml');

    expect(controller.hasTrack, isFalse);
    expect(fakePlayer.configuredSource, isNull);
    expect(checkedAssets, hasLength(5));
  });

  test('does not throw when configuring the audio context fails', () async {
    final controller = createController(
      setAudioContext: (_) async {
        throw StateError('audio plugin unavailable');
      },
    );

    await expectLater(
      controller.prepare('musicxml_preload/001.musicxml'),
      completes,
    );

    expect(controller.hasTrack, isFalse);
    expect(fakePlayer.calls, isEmpty);
  });

  test('clears the track when the player rejects the source', () async {
    final controller = createController(assetExists: (_) async => true);
    fakePlayer.failOnSetSource = true;

    await expectLater(
      controller.prepare('musicxml_preload/001.musicxml'),
      completes,
    );

    expect(controller.hasTrack, isFalse);
  });

  test('ignores a stale preparation after a newer operation starts', () async {
    final assetCheck = Completer<bool>();
    final controller = createController(assetExists: (_) => assetCheck.future);

    final firstPreparation = controller.prepare(
      'musicxml_preload/first.musicxml',
    );
    await Future<void>.delayed(Duration.zero);

    await controller.prepare(r'C:\scores\second.musicxml', volume: 0.25);
    assetCheck.complete(true);
    await firstPreparation;

    expect(controller.hasTrack, isFalse);
    expect(fakePlayer.configuredSource, isNull);
  });

  test('clamps volume and starts playback from the beginning', () async {
    final controller = createController(assetExists: (_) async => true);

    await controller.prepare('musicxml_preload/001.musicxml', volume: 4);
    await controller.playFromStart();

    expect(fakePlayer.configuredVolume, 1.0);
    expect(fakePlayer.playedSources, hasLength(1));
    expect(fakePlayer.calls, contains('stop'));
    expect(fakePlayer.calls, contains('play:1.0'));
    expect(
      await controller.getCurrentPosition(),
      const Duration(milliseconds: 250),
    );
  });

  test('dispose is idempotent and prevents later operations', () async {
    final controller = createController(assetExists: (_) async => true);

    await controller.prepare('musicxml_preload/001.musicxml');
    await controller.dispose();
    await controller.dispose();
    await controller.playFromStart();
    await controller.stop();

    expect(controller.hasTrack, isFalse);
    expect(fakePlayer.disposed, isTrue);
    expect(fakePlayer.calls.where((call) => call == 'dispose'), hasLength(1));
    expect(await controller.getCurrentPosition(), isNull);
  });
}
