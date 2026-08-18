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
