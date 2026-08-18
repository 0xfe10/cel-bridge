import 'dart:async';
import 'dart:isolate';

import '../../cel_exception.dart';
import 'native_worker_isolate.dart';

final class NativeWorkerClient {
  NativeWorkerClient._();

  static final NativeWorkerClient instance = NativeWorkerClient._();

  final Map<int, Completer<String>> _pending = {};
  ReceivePort? _replies;
  ReceivePort? _errors;
  ReceivePort? _exits;
  Isolate? _isolate;
  SendPort? _worker;
  Future<void>? _started;
  int _nextRequestId = 0;
  int _spawnCount = 0;

  int get spawnCount => _spawnCount;

  Future<String> invoke(
    String operation,
    String first,
    String second,
    String third,
  ) async {
    await start();
    final worker = _worker;
    final replies = _replies;
    if (worker == null || replies == null) {
      throw const CelBridgeException(
        code: 'internal_error',
        message: 'native CEL worker is not running',
      );
    }
    final requestId = _nextRequestId++;
    final completer = Completer<String>();
    _pending[requestId] = completer;
    worker.send([requestId, operation, first, second, third, replies.sendPort]);
    return completer.future;
  }

  Future<void> start() {
    return _started ??= _start();
  }

  Future<void> closeForTesting() async {
    final pending = Map<int, Completer<String>>.from(_pending);
    _reset();
    for (final completer in pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const CelBridgeException(
            code: 'internal_error',
            message: 'native CEL worker exited',
          ),
        );
      }
    }
  }

  Future<void> _start() async {
    final ready = ReceivePort();
    final replies = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();
    try {
      final isolate = await Isolate.spawn(
        nativeWorkerMain,
        ready.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        errorsAreFatal: true,
      );
      _spawnCount += 1;
      final worker = await ready.first;
      if (worker is! SendPort) {
        throw StateError('native CEL worker did not send a SendPort');
      }
      _isolate = isolate;
      _worker = worker;
      _replies = replies;
      _errors = errors;
      _exits = exits;
      replies.listen(_onReply);
      errors.listen(_onWorkerError);
      exits.listen((_) => _failAll('native CEL worker exited'));
    } catch (error) {
      replies.close();
      errors.close();
      exits.close();
      _reset();
      throw CelBridgeException(
        code: 'native_library_load_failed',
        message: 'failed to start native CEL worker: $error',
      );
    } finally {
      ready.close();
    }
  }

  void _onReply(Object? message) {
    if (message is! List || message.length < 3) {
      return;
    }
    final requestId = message[0] as int;
    final success = message[1] as bool;
    final payload = message[2] as String;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
    if (success) {
      completer.complete(payload);
      return;
    }
    completer.completeError(
      CelBridgeException(
        code: 'native_library_load_failed',
        message: 'native CEL runtime call failed: $payload',
      ),
    );
  }

  void _onWorkerError(Object? message) {
    _failAll('native CEL worker failed: $message');
  }

  void _failAll(String message) {
    final pending = Map<int, Completer<String>>.from(_pending);
    _reset();
    final error = CelBridgeException(code: 'internal_error', message: message);
    for (final completer in pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  void _reset() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _worker = null;
    _replies?.close();
    _replies = null;
    _errors?.close();
    _errors = null;
    _exits?.close();
    _exits = null;
    _pending.clear();
    _started = null;
  }
}
