import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/piano_audio_service.dart';
import 'package:app_music1/core/core.dart';
import 'package:app_music1/game/metronome_controller.dart';

class _FakeAudioService extends PianoAudioService {
  final List<bool> accents = [];

  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {
    accents.add(isAccent);
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

  test('plays every beat crossed after a delayed update', () async {
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
    timeSource.advance(const Duration(milliseconds: 1500));
    engine.update();
    await metronome.update();

    expect(audioService.accents, [true, false, true, false]);
  });
}
