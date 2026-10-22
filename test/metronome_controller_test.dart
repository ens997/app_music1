import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/metronome_audio_output.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/game/metronome_controller.dart';

class _FakeAudioService implements MetronomeAudioOutput {
  final List<bool> accents = [];
  final List<double> volumes = [];

  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {
    accents.add(isAccent);
    volumes.add(volume);
  }
}

void main() {
  test('plays the first beat at tick zero', () async {
    final timeSource = FakeTimeSource();
    final audioService = _FakeAudioService();
    final engine = TicksEngine(timeSource: timeSource);
    final metronome = MetronomeController(
      ticksEngine: engine,
      timeSignature: TimeSignature(4, 4),
      audioService: audioService,
    );

    engine.start();
    metronome.start();
    await metronome.update();

    expect(audioService.accents, [true]);
  });

  test('skips overdue beats after a delayed update', () async {
    final timeSource = FakeTimeSource();
    final audioService = _FakeAudioService();
    final engine = TicksEngine(timeSource: timeSource);
    final metronome = MetronomeController(
      ticksEngine: engine,
      timeSignature: TimeSignature(4, 4),
      audioService: audioService,
    );

    engine.start();
    metronome.start();
    await metronome.update();
    timeSource.advance(const Duration(milliseconds: 1500));
    engine.update();
    await metronome.update();

    expect(audioService.accents, [true, false]);
  });

  test('passes the configured accent volume through the audio port', () async {
    final timeSource = FakeTimeSource();
    final audioService = _FakeAudioService();
    final engine = TicksEngine(timeSource: timeSource);
    final metronome = MetronomeController(
      ticksEngine: engine,
      timeSignature: TimeSignature(4, 4),
      audioService: audioService,
    )..setVolume(0.8);

    engine.start();
    metronome.start();
    await metronome.update();

    expect(audioService.volumes, [closeTo(0.68, 0.0001)]);
  });

  test(
    'uses eighth-note pulses and accents beats one and four in 6/8',
    () async {
      final timeSource = FakeTimeSource();
      final audioService = _FakeAudioService();
      final engine = TicksEngine(timeSource: timeSource);
      final metronome = MetronomeController(
        ticksEngine: engine,
        timeSignature: TimeSignature(6, 8),
        audioService: audioService,
      );

      engine.start();
      metronome.start();
      await metronome.update();

      timeSource.advance(const Duration(milliseconds: 250));
      engine.update();
      await metronome.update();
      timeSource.advance(const Duration(milliseconds: 250));
      engine.update();
      await metronome.update();
      timeSource.advance(const Duration(milliseconds: 250));
      engine.update();
      await metronome.update();

      expect(audioService.accents, [true, false, false, true]);
      expect(metronome.currentBeat, 4);
    },
  );
}
