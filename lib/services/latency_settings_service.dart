import 'package:shared_preferences/shared_preferences.dart';

import '../core/globals.dart';

class LatencySettingsService {
  static const _audioLatencyKey = 'audio_latency_ms';
  static const _inputLatencyKey = 'input_latency_ms';

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    audioLatencyMs.value = preferences.getInt(_audioLatencyKey) ?? 0;
    inputLatencyMs.value = preferences.getInt(_inputLatencyKey) ?? 0;
  }

  static Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_audioLatencyKey, audioLatencyMs.value);
    await preferences.setInt(_inputLatencyKey, inputLatencyMs.value);
  }
}
