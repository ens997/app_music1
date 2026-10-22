import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/audio_service_lifecycle.dart';

void main() {
  test('coalesces concurrent initialization and enters ready state', () async {
    final lifecycle = AudioServiceLifecycle();
    final initializationGate = Completer<bool>();
    var initializationCalls = 0;

    final firstInitialization = lifecycle.initialize(() {
      initializationCalls++;
      return initializationGate.future;
    });
    final secondInitialization = lifecycle.initialize(() async {
      initializationCalls++;
      return true;
    });

    expect(lifecycle.state, AudioServiceState.initializing);
    expect(initializationCalls, 1);

    initializationGate.complete(true);
    await Future.wait([firstInitialization, secondInitialization]);

    expect(lifecycle.state, AudioServiceState.ready);
  });

  test('records unavailable audio without throwing', () async {
    final lifecycle = AudioServiceLifecycle();

    await lifecycle.initialize(() async => false);

    expect(lifecycle.state, AudioServiceState.unavailable);
    await lifecycle.initialize(() async => true);
    expect(lifecycle.state, AudioServiceState.unavailable);
  });

  test(
    'marks failed initialization unavailable and avoids retry storms',
    () async {
      final lifecycle = AudioServiceLifecycle();
      var initializationCalls = 0;

      await expectLater(
        lifecycle.initialize(() async {
          initializationCalls++;
          throw StateError('initialization');
        }),
        throwsStateError,
      );
      expect(lifecycle.state, AudioServiceState.unavailable);

      await lifecycle.initialize(() async {
        initializationCalls++;
        return true;
      });
      expect(initializationCalls, 1);
      expect(lifecycle.state, AudioServiceState.unavailable);
    },
  );

  test('waits for initialization before disposing resources', () async {
    final lifecycle = AudioServiceLifecycle();
    final initializationGate = Completer<bool>();
    final events = <String>[];

    final initialization = lifecycle.initialize(() {
      events.add('initialize');
      return initializationGate.future;
    });
    final disposal = lifecycle.dispose(() async {
      events.add('dispose');
    });

    expect(lifecycle.state, AudioServiceState.disposing);
    expect(events, ['initialize']);

    initializationGate.complete(true);
    await Future.wait([initialization, disposal]);

    expect(events, ['initialize', 'dispose']);
    expect(lifecycle.state, AudioServiceState.disposed);
  });

  test('dispose is idempotent and prevents later initialization', () async {
    final lifecycle = AudioServiceLifecycle();
    var disposalCalls = 0;
    var initializationCalls = 0;

    await Future.wait([
      lifecycle.dispose(() async => disposalCalls++),
      lifecycle.dispose(() async => disposalCalls++),
    ]);
    await lifecycle.initialize(() async {
      initializationCalls++;
      return true;
    });

    expect(disposalCalls, 1);
    expect(initializationCalls, 0);
    expect(lifecycle.state, AudioServiceState.disposed);
  });
}
