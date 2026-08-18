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
  Future<String> validate(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) async {
    try {
      return celBridgeValidateJS(environmentJson, source, optionsJson);
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
    String variablesJson, [
    String optionsJson = '',
  ]) async {
    try {
      return celBridgeEvaluateJS(
        environmentJson,
        source,
        variablesJson,
        optionsJson,
      );
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> evaluateMany(
    String environmentJson,
    String sourcesJson,
    String variablesJson,
  ) async {
    try {
      return celBridgeEvaluateManyJS(
        environmentJson,
        sourcesJson,
        variablesJson,
      );
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> evaluateRequests(
    String environmentJson,
    String requestsJson, [
    String optionsJson = '',
  ]) async {
    try {
      return celBridgeEvaluateRequestsJS(
        environmentJson,
        requestsJson,
        optionsJson,
      );
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> prepare(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]) async {
    try {
      return celBridgePrepareJS(environmentJson, source, optionsJson);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> evaluateProgram(
    String programId,
    String variablesJson, [
    String optionsJson = '',
  ]) async {
    try {
      return celBridgeEvaluateProgramJS(programId, variablesJson, optionsJson);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> releaseProgram(String programId) async {
    try {
      return celBridgeReleaseProgramJS(programId);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> close() async {
    try {
      return celBridgeCloseJS();
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }

  @override
  Future<String> create([String optionsJson = '']) async {
    try {
      return celBridgeCreateJS(optionsJson);
    } catch (error) {
      throw CelBridgeException(
        code: 'wasm_load_failed',
        message: 'Wasm CEL runtime call failed: $error',
      );
    }
  }
}
