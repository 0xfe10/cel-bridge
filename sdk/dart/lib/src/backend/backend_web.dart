import '../cel_exception.dart';
import '../cel_runtime_options.dart';
import 'backend_api.dart';
import 'web/go_wasm_interop.dart';
import 'web/wasm_loader.dart';

Future<CelBackend> createBackend(CelRuntimeOptions options) async {
  try {
    await loadGoWasm(options);
    return const _WebBackend();
  } catch (error) {
    if (error is CelBridgeException) rethrow;
    throw CelBridgeException(
      code: 'wasm_load_failed',
      message: 'failed to load CEL Wasm runtime: $error',
    );
  }
}

final class _WebBackend implements CelBackend {
  const _WebBackend();

  @override
  Future<String> runtimeInfo() async => celBridgeRuntimeInfoJS();

  @override
  Future<String> validate(String environmentJson, String source) async {
    try {
      return celBridgeValidateJS(environmentJson, source);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson,
  ) async {
    try {
      return celBridgeEvaluateJS(environmentJson, source, variablesJson);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }
}
