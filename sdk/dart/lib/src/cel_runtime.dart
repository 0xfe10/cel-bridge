import 'backend/backend.dart' as backend;
import 'cel_batch_result.dart';
import 'cel_evaluation_request.dart';
import 'cel_exception.dart';
import 'cel_request_result.dart';
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
  static bool _needsCreate = false;

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
      final profile = options.profile;
      if (_needsCreate || (profile != null && profile.isNotEmpty)) {
        decodeCreatedRuntime(
          await runtimeBackend.create(encodeCreateOptions(profile: profile)),
        );
        _needsCreate = false;
      }
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
  bool _disposed = false;

  Future<CelValidationResult> validate({
    required Map<String, Object?> environment,
    required String source,
    Object? expectedResultType,
  }) async {
    _ensureOpen();
    _rejectNul(source, 'source');
    try {
      final raw = await _backend.validate(
        encodeEnvironment(environment),
        source,
        encodeRequestOptions(expectedResultType: expectedResultType),
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
    Object? expectedResultType,
    int? deadlineMs,
  }) async {
    _ensureOpen();
    _rejectNul(source, 'source');
    try {
      final raw = await _backend.evaluate(
        encodeEnvironment(environment),
        source,
        encodeVariables(variables),
        encodeRequestOptions(
          expectedResultType: expectedResultType,
          deadlineMs: deadlineMs,
        ),
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
    _ensureOpen();
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

  Future<List<CelRequestResult>> evaluateRequests({
    required Map<String, Object?> environment,
    required List<CelEvaluationRequest> requests,
    Object? expectedResultType,
    int? deadlineMs,
  }) async {
    _ensureOpen();
    _validateRequests(requests);
    if (requests.isEmpty) {
      return const [];
    }
    try {
      final raw = await _backend.evaluateRequests(
        encodeEnvironment(environment),
        encodeEvaluationRequests(requests),
        encodeRequestOptions(
          expectedResultType: expectedResultType,
          deadlineMs: deadlineMs,
        ),
      );
      return decodeRequests(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode per-request batch: $error',
      );
    }
  }

  Future<String> prepare({
    required Map<String, Object?> environment,
    required String source,
    Object? expectedResultType,
  }) async {
    _ensureOpen();
    _rejectNul(source, 'source');
    try {
      final raw = await _backend.prepare(
        encodeEnvironment(environment),
        source,
        encodeRequestOptions(expectedResultType: expectedResultType),
      );
      return decodePrepare(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode prepare request: $error',
      );
    }
  }

  Future<CelValue> evaluateProgram({
    required String programId,
    required Map<String, Object?> variables,
    Object? expectedResultType,
    int? deadlineMs,
  }) async {
    _ensureOpen();
    _rejectNul(programId, 'programId');
    try {
      final raw = await _backend.evaluateProgram(
        programId,
        encodeVariables(variables),
        encodeRequestOptions(
          expectedResultType: expectedResultType,
          deadlineMs: deadlineMs,
        ),
      );
      return decodeEvaluation(raw);
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode program evaluation request: $error',
      );
    }
  }

  Future<void> releaseProgram(String programId) async {
    _ensureOpen();
    _rejectNul(programId, 'programId');
    try {
      decodeAck(await _backend.releaseProgram(programId));
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'failed to encode release request: $error',
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _initialization = null;
    _needsCreate = true;
    try {
      decodeAck(await _backend.close());
    } on CelBridgeException {
      rethrow;
    } catch (error) {
      throw CelBridgeException(
        code: 'internal_error',
        message: 'failed to dispose CEL runtime: $error',
      );
    }
  }

  void _ensureOpen() {
    if (_disposed) {
      throw const CelBridgeException(
        code: 'runtime_closed',
        message: 'runtime has been disposed',
      );
    }
  }
}

void _validateRequests(List<CelEvaluationRequest> requests) {
  if (requests.length > maxBatchExpressions) {
    throw CelBridgeException(
      code: 'invalid_request',
      message: 'batch exceeds $maxBatchExpressions expressions',
    );
  }
  final seen = <String>{};
  for (final request in requests) {
    _rejectNul(request.id, 'id');
    if (request.id.trim().isEmpty) {
      throw const CelBridgeException(
        code: 'invalid_request',
        message: 'request id is required',
      );
    }
    if (!seen.add(request.id)) {
      throw CelBridgeException(
        code: 'invalid_request',
        message: 'duplicate request id "${request.id}"',
      );
    }
    final hasSource =
        request.source != null && request.source!.trim().isNotEmpty;
    final hasProgram =
        request.programId != null && request.programId!.trim().isNotEmpty;
    if (hasSource == hasProgram) {
      throw const CelBridgeException(
        code: 'invalid_request',
        message: 'request must include exactly one of source or programId',
      );
    }
    if (hasSource) {
      _rejectNul(request.source!, 'source');
    }
    if (hasProgram) {
      _rejectNul(request.programId!, 'programId');
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
