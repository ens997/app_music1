import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/instrument_sample_generator.dart';
import 'package:app_music1/audio/instrument_type.dart';

void main() {
  test('generates missing notes for each sampled instrument', () async {
    final fluteSamples = await generateInstrumentSampleBatch(
      InstrumentType.flute,
      ['C4'],
    );
    final violinSamples = await generateInstrumentSampleBatch(
      InstrumentType.violin,
      ['G3', 'E7'],
    );

    expect(fluteSamples.keys, ['C4']);
    expect(fluteSamples['C4'], isNotEmpty);
    expect(violinSamples.keys, ['G3', 'E7']);
    expect(violinSamples['G3'], isNotEmpty);
    expect(violinSamples['E7'], isNotEmpty);
  });

  test(
    'generates held-note samples through the same isolate batch API',
    () async {
      final fluteSamples = await generateInstrumentSampleBatch(
        InstrumentType.flute,
        ['A4'],
        sustained: true,
      );
      final violinSamples = await generateInstrumentSampleBatch(
        InstrumentType.violin,
        ['A4'],
        sustained: true,
      );

      expect(fluteSamples['A4'], isNotEmpty);
      expect(violinSamples['A4'], isNotEmpty);
      expect(fluteSamples['A4'], isNot(violinSamples['A4']));
    },
  );
}
