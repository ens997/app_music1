import 'instrument_audio_output.dart';
import 'flute_audio_service.dart';
import 'instrument_type.dart';
import 'metronome_audio_output.dart';
import 'piano_audio_service.dart';
import 'violin_audio_service.dart';

class InstrumentAudioBackend {
  final InstrumentAudioOutput instrument;
  final MetronomeAudioOutput? metronome;

  const InstrumentAudioBackend({required this.instrument, this.metronome});
}

class InstrumentAudioRegistry {
  static const List<InstrumentType> availableInstruments = [
    InstrumentType.piano,
    InstrumentType.flute,
    InstrumentType.violin,
  ];

  static bool isAvailable(InstrumentType instrument) {
    return availableInstruments.contains(instrument);
  }

  static InstrumentAudioBackend create(InstrumentType instrument) {
    return switch (instrument) {
      InstrumentType.piano => _createPianoBackend(),
      InstrumentType.flute => _createFluteBackend(),
      InstrumentType.violin => _createViolinBackend(),
    };
  }

  static InstrumentAudioBackend _createPianoBackend() {
    final piano = PianoAudioService();
    return InstrumentAudioBackend(instrument: piano, metronome: piano);
  }

  static InstrumentAudioBackend _createFluteBackend() {
    final flute = FluteAudioService();
    return InstrumentAudioBackend(instrument: flute, metronome: flute);
  }

  static InstrumentAudioBackend _createViolinBackend() {
    final violin = ViolinAudioService();
    return InstrumentAudioBackend(instrument: violin, metronome: violin);
  }
}
