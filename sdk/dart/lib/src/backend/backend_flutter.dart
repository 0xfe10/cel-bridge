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
  Future<String> validate(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) {
    return _invoke('validate', {
      'environment': environmentJson,
      'source': source,
      'options': optionsJson,
    });
  }

  @override
  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson, [
    String optionsJson = '',
  ]) {
    return _invoke('evaluate', {
      'environment': environmentJson,
      'source': source,
      'variables': variablesJson,
      'options': optionsJson,
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

  @override
  Future<String> evaluateRequests(
    String environmentJson,
    String requestsJson, [
    String optionsJson = '',
  ]) {
    return _invoke('evaluateRequests', {
      'environment': environmentJson,
      'requests': requestsJson,
      'options': optionsJson,
    });
  }

  @override
  Future<String> prepare(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) {
    return _invoke('prepare', {
      'environment': environmentJson,
      'source': source,
      'options': optionsJson,
    });
  }

  @override
  Future<String> evaluateProgram(
    String programId,
    String variablesJson, [
    String optionsJson = '',
  ]) {
    return _invoke('evaluateProgram', {
      'programId': programId,
      'variables': variablesJson,
      'options': optionsJson,
    });
  }

  @override
  Future<String> releaseProgram(String programId) {
    return _invoke('releaseProgram', {'programId': programId});
  }

  @override
  Future<String> close() => _invoke('close');

  @override
  Future<String> create([String optionsJson = '']) {
    return _invoke('create', {'options': optionsJson});
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
  Future<String> validate(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) {
    return _invoke('validate', environmentJson, source, optionsJson);
  }

  @override
  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson, [
    String optionsJson = '',
  ]) {
    return _invoke(
      'evaluate',
      environmentJson,
      source,
      variablesJson,
      optionsJson,
    );
  }

  @override
  Future<String> evaluateMany(
    String environmentJson,
    String sourcesJson,
    String variablesJson,
  ) {
    return _invoke('evaluateMany', environmentJson, sourcesJson, variablesJson);
  }

  @override
  Future<String> evaluateRequests(
    String environmentJson,
    String requestsJson, [
    String optionsJson = '',
  ]) {
    return _invoke(
      'evaluateRequests',
      environmentJson,
      requestsJson,
      optionsJson,
    );
  }

  @override
  Future<String> prepare(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) {
    return _invoke('prepare', environmentJson, source, optionsJson);
  }

  @override
  Future<String> evaluateProgram(
    String programId,
    String variablesJson, [
    String optionsJson = '',
  ]) {
    return _invoke('evaluateProgram', programId, variablesJson, optionsJson);
  }

  @override
  Future<String> releaseProgram(String programId) {
    return _invoke('releaseProgram', programId);
  }

  @override
  Future<String> close() => _invoke('close');

  @override
  Future<String> create([String optionsJson = '']) {
    return _invoke('create', optionsJson);
  }

  Future<String> _invoke(
    String operation, [
    String first = '',
    String second = '',
    String third = '',
    String fourth = '',
  ]) async {
    try {
      return await invokeNative(operation, first, second, third, fourth);
    } catch (error) {
      if (error is CelBridgeException) rethrow;
      throw CelBridgeException(
        code: 'native_library_load_failed',
        message: 'native CEL runtime call failed: $error',
      );
    }
  }
}
