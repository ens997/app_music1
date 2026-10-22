abstract interface class MetronomeAudioOutput {
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  });
}

class SilentMetronomeAudioOutput implements MetronomeAudioOutput {
  const SilentMetronomeAudioOutput();

  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {}
}
