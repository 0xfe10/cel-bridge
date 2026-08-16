import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'native_bindings.dart';

Future<String> invokeNative(
  String operation,
  String first,
  String second,
  String third,
) {
  return Isolate.run(() => _invokeNative(operation, first, second, third));
}

String _invokeNative(
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
