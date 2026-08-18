import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

void nativeWorkerMain(SendPort handshake) {
  final incoming = ReceivePort();
  handshake.send(incoming.sendPort);
  incoming.listen((message) {
    if (message is! List || message.length < 7) {
      return;
    }
    final requestId = message[0] as int;
    final operation = message[1] as String;
    final first = message[2] as String;
    final second = message[3] as String;
    final third = message[4] as String;
    final fourth = message[5] as String;
    final reply = message[6] as SendPort;
    try {
      reply.send([
        requestId,
        true,
        invokeNativeSync(operation, first, second, third, fourth),
      ]);
    } catch (error) {
      reply.send([requestId, false, error.toString()]);
    }
  });
}

String invokeNativeSync(
  String operation,
  String first,
  String second,
  String third, [
  String fourth = '',
]) {
  return switch (operation) {
    'version' => _read(celBridgeVersion()),
    'runtimeInfo' => _read(celBridgeRuntimeInfo()),
    'validate' => _callThree(celBridgeValidateOptions, first, second, third),
    'evaluate' => _callFour(
      celBridgeEvaluateOptions,
      first,
      second,
      third,
      fourth,
    ),
    'evaluateMany' => _callThree(celBridgeEvaluateMany, first, second, third),
    'evaluateRequests' => _callThree(
      celBridgeEvaluateRequests,
      first,
      second,
      third,
    ),
    'prepare' => _callThree(celBridgePrepare, first, second, third),
    'evaluateProgram' => _callThree(
      celBridgeEvaluateProgram,
      first,
      second,
      third,
    ),
    'releaseProgram' => _callOne(celBridgeReleaseProgram, first),
    'close' => _read(celBridgeClose()),
    'create' => _callOne(celBridgeCreate, first),
    _ => throw ArgumentError.value(operation, 'operation'),
  };
}

String _callFour(
  Pointer<Utf8> Function(
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
  )
  function,
  String first,
  String second,
  String third,
  String fourth,
) {
  final firstPointer = first.toNativeUtf8();
  final secondPointer = second.toNativeUtf8();
  final thirdPointer = third.toNativeUtf8();
  final fourthPointer = fourth.toNativeUtf8();
  try {
    return _read(
      function(firstPointer, secondPointer, thirdPointer, fourthPointer),
    );
  } finally {
    calloc
      ..free(firstPointer)
      ..free(secondPointer)
      ..free(thirdPointer)
      ..free(fourthPointer);
  }
}

String _callThree(
  Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>) function,
  String first,
  String second,
  String third,
) {
  final firstPointer = first.toNativeUtf8();
  final secondPointer = second.toNativeUtf8();
  final thirdPointer = third.toNativeUtf8();
  try {
    return _read(function(firstPointer, secondPointer, thirdPointer));
  } finally {
    calloc
      ..free(firstPointer)
      ..free(secondPointer)
      ..free(thirdPointer);
  }
}

String _callOne(Pointer<Utf8> Function(Pointer<Utf8>) function, String first) {
  final firstPointer = first.toNativeUtf8();
  try {
    return _read(function(firstPointer));
  } finally {
    calloc.free(firstPointer);
  }
}

String _read(Pointer<Utf8> value) {
  if (value == nullptr) {
    throw StateError('native CEL runtime returned null');
  }
  try {
    return value.toDartString();
  } finally {
    celBridgeFree(value);
  }
}
