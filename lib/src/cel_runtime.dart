import 'backend/backend.dart' as backend;
import 'cel_exception.dart';
import 'cel_runtime_options.dart';
import 'cel_validation_result.dart';
import 'cel_value.dart';
import 'runtime_info.dart';
import 'wire/decoder.dart';
import 'wire/encoder.dart';

final class CelRuntime {
  CelRuntime._(this._backend, this.info);

  static Future<CelRuntime>? _initialization;

  static Future<CelRuntime> initialize({
    CelRuntimeOptions options = const CelRuntimeOptions(),
  }) {
    return _initialization ??= _initialize(options);
  }

  static Future<CelRuntime> _initialize(CelRuntimeOptions options) async {
    try {
      final runtimeBackend = await backend.createBackend(options);
      final info = decodeRuntimeInfo(await runtimeBackend.runtimeInfo());
      return CelRuntime._(runtimeBackend, info);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'internal_error',
        message: 'failed to initialize CEL runtime: $error',
      );
    }
  }

  final backend.CelBackend _backend;
  final CelRuntimeInfo info;

  Future<CelValidationResult> validate({
    required Map<String, Object?> environment,
    required String source,
  }) async {
    try {
      final raw = await _backend.validate(
        encodeEnvironment(environment),
        source,
      );
      return decodeValidation(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode validation request: $error',
      );
    }
  }

  Future<CelValue> evaluate({
    required Map<String, Object?> environment,
    required String source,
    required Map<String, Object?> variables,
  }) async {
    try {
      final raw = await _backend.evaluate(
        encodeEnvironment(environment),
        source,
        encodeVariables(variables),
      );
      return decodeEvaluation(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode evaluation request: $error',
      );
    }
  }
}
