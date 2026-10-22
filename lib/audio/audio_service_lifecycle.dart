import 'package:flutter/foundation.dart';

enum AudioServiceState {
  idle,
  initializing,
  ready,
  unavailable,
  disposing,
  disposed,
}

typedef AudioResourceInitializer = Future<bool> Function();
typedef AudioResourceDisposer = Future<void> Function();

class AudioServiceLifecycle {
  AudioServiceState _state = AudioServiceState.idle;
  Future<void>? _initialization;
  Future<void>? _disposal;

  AudioServiceState get state => _state;

  Future<void> initialize(AudioResourceInitializer initializeResources) {
    if (_state != AudioServiceState.idle) {
      return _initialization ?? Future<void>.value();
    }

    _state = AudioServiceState.initializing;
    final operation = _initialize(initializeResources);
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize(AudioResourceInitializer initializeResources) async {
    try {
      final isAvailable = await initializeResources();
      if (_state == AudioServiceState.initializing) {
        _state = isAvailable
            ? AudioServiceState.ready
            : AudioServiceState.unavailable;
      }
    } catch (_) {
      if (_state == AudioServiceState.initializing) {
        _state = AudioServiceState.unavailable;
      }
      rethrow;
    } finally {
      _initialization = null;
    }
  }

  Future<void> dispose(AudioResourceDisposer disposeResources) {
    final existingDisposal = _disposal;
    if (existingDisposal != null) return existingDisposal;
    if (_state == AudioServiceState.disposed) return Future<void>.value();

    _state = AudioServiceState.disposing;
    final initialization = _initialization;
    final operation = _dispose(initialization, disposeResources);
    _disposal = operation;
    return operation;
  }

  Future<void> _dispose(
    Future<void>? initialization,
    AudioResourceDisposer disposeResources,
  ) async {
    try {
      if (initialization != null) {
        try {
          await initialization;
        } catch (error) {
          debugPrint('Audio initialization failed before disposal: $error');
        }
      }
      await disposeResources();
    } finally {
      _state = AudioServiceState.disposed;
    }
  }
}
