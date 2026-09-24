import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';

void main() {
  group('TicksEngine with FakeTimeSource', () {
    test(
      'converts elapsed time to ticks independently of update frequency',
      () {
        final timeSource = FakeTimeSource();
        final engine = TicksEngine(initialBpm: 120, timeSource: timeSource);

        engine.start();
        timeSource.advance(const Duration(milliseconds: 16));
        engine.update();
        timeSource.advance(const Duration(milliseconds: 200));
        engine.update();

        expect(engine.currentTick, 207);
      },
    );

    test('preserves elapsed musical time when BPM changes', () {
      final timeSource = FakeTimeSource();
      final engine = TicksEngine(initialBpm: 120, timeSource: timeSource);

      engine.start();
      timeSource.advance(const Duration(milliseconds: 500));
      engine.update();
      engine.setBpm(60);
      timeSource.advance(const Duration(seconds: 1));
      engine.update();

      expect(engine.currentTick, 960);
    });

    test('does not advance while paused and resumes from the same time', () {
      final timeSource = FakeTimeSource();
      final engine = TicksEngine(timeSource: timeSource);

      engine.start();
      timeSource.advance(const Duration(milliseconds: 250));
      engine.update();
      engine.pause();
      timeSource.advance(const Duration(seconds: 1));
      engine.update();

      expect(engine.currentTick, 240);

      engine.resume();
      timeSource.advance(const Duration(milliseconds: 250));
      engine.update();

      expect(engine.currentTick, 480);
    });

    test('applies configured audio and input latency to input time', () {
      final timeSource = FakeTimeSource();
      final engine = TicksEngine(timeSource: timeSource)
        ..audioLatencyMs = 50
        ..inputLatencyMs = 30;

      engine.start();
      timeSource.advance(const Duration(milliseconds: 100));
      engine.update();

      expect(engine.currentTick, 96);
      expect(engine.tickForInput, 19);
    });

    test('reset clears the source and accumulated ticks', () {
      final timeSource = FakeTimeSource();
      final engine = TicksEngine(timeSource: timeSource);

      engine.start();
      timeSource.advance(const Duration(milliseconds: 500));
      engine.update();
      engine.reset();

      expect(engine.currentTick, 0);
      expect(engine.elapsedMilliseconds, 0);
      expect(engine.isRunning, isFalse);
    });
  });
}
