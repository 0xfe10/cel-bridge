import 'backend/backend.dart' as backend;
import 'cel_batch_result.dart';
import 'cel_exception.dart';
import 'cel_runtime_options.dart';
import 'cel_validation_result.dart';
import 'cel_value.dart';
import 'runtime_info.dart';
import 'wire/decoder.dart';
import 'wire/encoder.dart';

const maxBatchExpressions = 256;

final class CelRuntime {
  CelRuntime._(this._backend, this.info);

  static Future<CelRuntime>? _initialization;

  static Future<CelRuntime> initialize({
    CelRuntimeOptions options = const CelRuntimeOptions(),
  }) {
    final initialization = _initialization;
    if (initialization != null) return initialization;
    final future = _initializeWithRetry(options);
    _initialization = future;
    return future;
  }

  static Future<CelRuntime> _initializeWithRetry(
    CelRuntimeOptions options,
  ) async {
    try {
      return await _initialize(options);
    } catch (error, stackTrace) {
      _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    }
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
    _rejectNul(source, 'source');
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
    _rejectNul(source, 'source');
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

  Future<List<CelBatchResult>> evaluateMany({
    required Map<String, Object?> environment,
    required List<String> sources,
    required Map<String, Object?> variables,
  }) async {
    if (sources.length > maxBatchExpressions) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'batch exceeds $maxBatchExpressions expressions',
      );
    }
    for (final source in sources) {
      _rejectNul(source, 'source');
    }
    if (sources.isEmpty) {
      return const [];
    }
    try {
      final raw = await _backend.evaluateMany(
        encodeEnvironment(environment),
        encodeSources(sources),
        encodeVariables(variables),
      );
      return decodeBatch(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode batch evaluation request: $error',
      );
    }
  }
}

void _rejectNul(String value, String name) {
  if (value.contains('\u0000')) {
    throw CelBridgeException(
      code: 'invalid_request',
      message: '$name must not contain NUL characters',
    );
  }
}
