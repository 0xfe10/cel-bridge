import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

void nativeWorkerMain(SendPort handshake) {
  final incoming = ReceivePort();
  handshake.send(incoming.sendPort);
  incoming.listen((message) {
    if (message is! List || message.length < 6) {
      return;
    }
    final requestId = message[0] as int;
    final operation = message[1] as String;
    final first = message[2] as String;
    final second = message[3] as String;
    final third = message[4] as String;
    final reply = message[5] as SendPort;
    try {
      reply.send([
        requestId,
        true,
        invokeNativeSync(operation, first, second, third),
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
  String third,
) {
  return switch (operation) {
    'version' => _read(celBridgeVersion()),
    'runtimeInfo' => _read(celBridgeRuntimeInfo()),
    'validate' => _callTwo(celBridgeValidate, first, second),
    'evaluate' => _callThree(celBridgeEvaluate, first, second, third),
    'evaluateMany' => _callThree(celBridgeEvaluateMany, first, second, third),
    _ => throw ArgumentError.value(operation, 'operation'),
  };
}

String _callTwo(
  Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>) function,
  String first,
  String second,
) {
  final firstPointer = first.toNativeUtf8();
  final secondPointer = second.toNativeUtf8();
  try {
    return _read(function(firstPointer, secondPointer));
  } finally {
    calloc
      ..free(firstPointer)
      ..free(secondPointer);
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
