import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_music1/audio/instrument_audio_registry.dart';
import 'package:app_music1/audio/instrument_type.dart';
import 'package:app_music1/audio/flute_audio_service.dart';
import 'package:app_music1/audio/piano_audio_service.dart';
import 'package:app_music1/screens/settings_screen.dart';
import 'package:app_music1/services/instrument_settings_service.dart';
import 'package:app_music1/audio/violin_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('only instruments with a backend are exposed as available', () {
    expect(InstrumentAudioRegistry.availableInstruments, [
      InstrumentType.piano,
      InstrumentType.flute,
      InstrumentType.violin,
    ]);
    expect(InstrumentAudioRegistry.isAvailable(InstrumentType.violin), isTrue);
    expect(InstrumentAudioRegistry.isAvailable(InstrumentType.flute), isTrue);
  });

  test('registry creates backends for all available instruments', () {
    expect(
      InstrumentAudioRegistry.create(InstrumentType.piano).instrument,
      isA<PianoAudioService>(),
    );
    final fluteBackend = InstrumentAudioRegistry.create(InstrumentType.flute);
    expect(fluteBackend.instrument, isA<FluteAudioService>());
    expect(fluteBackend.metronome, same(fluteBackend.instrument));
    final violinBackend = InstrumentAudioRegistry.create(InstrumentType.violin);
    expect(violinBackend.instrument, isA<ViolinAudioService>());
    expect(violinBackend.metronome, same(violinBackend.instrument));
  });

  test('loads piano by default and persists the selected instrument', () async {
    await InstrumentSettingsService.load();
    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.piano,
    );

    await InstrumentSettingsService.select(InstrumentType.piano);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('selected_instrument'), 'piano');
  });

  test('falls back to piano when stored instrument is unknown', () async {
    SharedPreferences.setMockInitialValues({'selected_instrument': 'banjo'});

    await InstrumentSettingsService.load();

    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.piano,
    );
  });

  test('loads and persists the selected flute', () async {
    await InstrumentSettingsService.load();
    await InstrumentSettingsService.select(InstrumentType.flute);

    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.flute,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('selected_instrument'), 'flute');

    await InstrumentSettingsService.load();
    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.flute,
    );
  });

  test('loads and persists the selected violin', () async {
    await InstrumentSettingsService.load();
    await InstrumentSettingsService.select(InstrumentType.violin);

    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.violin,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('selected_instrument'), 'violin');

    await InstrumentSettingsService.load();
    expect(
      InstrumentSettingsService.selectedInstrument.value,
      InstrumentType.violin,
    );
  });

  testWidgets('settings lists instruments with implemented audio', (
    tester,
  ) async {
    await InstrumentSettingsService.load();
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('Instrumento'), findsOneWidget);
    expect(find.text('Piano'), findsOneWidget);
    expect(find.text('Flauta'), findsNothing);
    expect(
      find.textContaining('sonidos de flauta y violín son sintéticos'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<InstrumentType>));
    await tester.pumpAndSettle();

    expect(find.text('Piano'), findsWidgets);
    expect(find.text('Violín'), findsWidgets);
    expect(find.text('Flauta'), findsWidgets);
  });
}
