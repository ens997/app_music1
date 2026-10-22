import 'audio_service_lifecycle.dart';

/// Audio backend for notes played through the selected instrument.
abstract interface class InstrumentAudioOutput {
  AudioServiceState get state;

  Future<void> initialize();

  Future<void> playNote(String pitch, {double volume = 0.85});

  Future<void> dispose();
}
