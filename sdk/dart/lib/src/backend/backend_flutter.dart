import 'dart:io';

import 'package:flutter/services.dart';

import '../cel_exception.dart';
import '../cel_runtime_options.dart';
import 'backend_api.dart';
import 'ffi/native_worker.dart';

Future<CelBackend> createBackend(CelRuntimeOptions _) {
  if (Platform.isIOS) return Future.value(const _IOSChannelBackend());
  return Future.value(const _FlutterNativeBackend());
}

final class _IOSChannelBackend implements CelBackend {
  const _IOSChannelBackend();

  static const _channel = MethodChannel('cel_bridge');

  @override
  Future<String> runtimeInfo() => _invoke('runtimeInfo');

  @override
  Future<String> validate(String environmentJson, String source) {
    return _invoke('validate', {
      'environment': environmentJson,
      'source': source,
    });
  }

  @override
  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson,
  ) {
    return _invoke('evaluate', {
      'environment': environmentJson,
      'source': source,
      'variables': variablesJson,
    });
  }

  @override
  Future<String> evaluateMany(
    String environmentJson,
    String sourcesJson,
    String variablesJson,
  ) {
    return _invoke('evaluateMany', {
      'environment': environmentJson,
      'sources': sourcesJson,
      'variables': variablesJson,
    });
  }

  Future<String> _invoke(
    String method, [
    Map<String, String>? arguments,
  ]) async {
    try {
      final value = await _channel.invokeMethod<String>(method, arguments);
      if (value == null) throw StateError('iOS plugin returned no JSON');
      return value;
    } on PlatformException catch (error) {
      throw CelBridgeException(
        code: error.code.isEmpty ? 'native_library_load_failed' : error.code,
        message: error.message ?? 'iOS CEL plugin call failed',
      );
    } catch (error) {
      throw CelBridgeException(
        code: 'native_library_load_failed',
        message: 'iOS CEL plugin call failed: $error',
      );
    }
  }
}

final class _FlutterNativeBackend implements CelBackend {
  const _FlutterNativeBackend();

  @override
  Future<String> runtimeInfo() => _invoke('runtimeInfo');

  @override
  Future<String> validate(String environmentJson, String source) {
    return _invoke('validate', environmentJson, source);
  }

  @override
  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson,
  ) {
    return _invoke('evaluate', environmentJson, source, variablesJson);
  }

  @override
  Future<String> evaluateMany(
    String environmentJson,
    String sourcesJson,
    String variablesJson,
  ) {
    return _invoke('evaluateMany', environmentJson, sourcesJson, variablesJson);
  }

  Future<String> _invoke(
    String operation, [
    String first = '',
    String second = '',
    String third = '',
  ]) async {
    try {
      return await invokeNative(operation, first, second, third);
    } catch (error) {
      if (error is CelBridgeException) rethrow;
      throw CelBridgeException(
        code: 'native_library_load_failed',
        message: 'native CEL runtime call failed: $error',
      );
    }
  }
}
