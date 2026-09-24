/// Fuente de tiempo monotónica inyectable para el motor musical.
abstract class TimeSource {
  int get elapsedMicroseconds;
  bool get isRunning;

  void start();
  void stop();
  void reset();
}

class StopwatchTimeSource implements TimeSource {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();

  @override
  void reset() => _stopwatch.reset();
}

class FakeTimeSource implements TimeSource {
  int _elapsedMicroseconds = 0;
  bool _isRunning = false;

  void advance(Duration duration) {
    if (_isRunning) {
      _elapsedMicroseconds += duration.inMicroseconds;
    }
  }

  @override
  int get elapsedMicroseconds => _elapsedMicroseconds;

  @override
  bool get isRunning => _isRunning;

  @override
  void start() => _isRunning = true;

  @override
  void stop() => _isRunning = false;

  @override
  void reset() {
    _elapsedMicroseconds = 0;
    _isRunning = false;
  }
}
