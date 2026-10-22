import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/instrument_audio_registry.dart';
import '../audio/instrument_type.dart';

class InstrumentSettingsService {
  static const _instrumentKey = 'selected_instrument';

  static final ValueNotifier<InstrumentType> selectedInstrument = ValueNotifier(
    InstrumentType.piano,
  );

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedName = preferences.getString(_instrumentKey);
    InstrumentType? storedInstrument;
    for (final instrument in InstrumentType.values) {
      if (instrument.name == storedName) {
        storedInstrument = instrument;
        break;
      }
    }

    selectedInstrument.value =
        storedInstrument != null &&
            InstrumentAudioRegistry.isAvailable(storedInstrument)
        ? storedInstrument
        : InstrumentType.piano;
  }

  static Future<void> select(InstrumentType instrument) async {
    if (!InstrumentAudioRegistry.isAvailable(instrument)) {
      throw ArgumentError.value(
        instrument,
        'instrument',
        'El instrumento todavía no está disponible',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_instrumentKey, instrument.name);
    selectedInstrument.value = instrument;
  }
}
