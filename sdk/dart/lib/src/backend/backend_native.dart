import '../cel_exception.dart';
import '../cel_runtime_options.dart';
import 'backend_api.dart';
import 'ffi/native_worker.dart';

Future<CelBackend> createBackend(CelRuntimeOptions options) async {
  return const _NativeBackend();
}

final class _NativeBackend implements CelBackend {
  const _NativeBackend();

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
