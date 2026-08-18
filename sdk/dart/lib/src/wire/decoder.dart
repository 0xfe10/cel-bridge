import 'dart:convert';

import '../cel_batch_result.dart';
import '../cel_exception.dart';
import '../cel_request_result.dart';
import '../cel_runtime_options.dart';
import '../cel_validation_result.dart';
import '../cel_value.dart';
import '../runtime_info.dart';

CelValidationResult decodeValidation(String raw) {
  final response = _response(raw);
  return _decodeResult(
    'validation result',
    () => CelValidationResult.fromJson(response['result']),
  );
}

CelValue decodeEvaluation(String raw) {
  final response = _response(raw);
  return _decodeResult(
    'evaluation result',
    () => CelValue.fromJson(response['result']),
  );
}

List<CelRequestResult> decodeRequests(String raw) {
  final response = _response(raw);
  final result = response['result'];
  if (result is! List) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'request batch result must be a list',
    );
  }
  return [for (final item in result) _decodeRequestItem(item)];
}

CelRequestResult _decodeRequestItem(Object? json) {
  final item = _object(json, 'request result');
  final id = item['id'];
  if (id is! String || id.isEmpty) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'request result.id must be a non-empty string',
    );
  }
  final ok = item['ok'];
  if (ok is! bool) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'request result.ok must be a boolean',
    );
  }
  if (!ok) {
    return CelRequestFailure(id, _bridgeError(item['error']));
  }
  return CelRequestSuccess(
    id,
    _decodeResult('request result', () => CelValue.fromJson(item['result'])),
  );
}

String decodePrepare(String raw) {
  final response = _response(raw);
  final result = _object(response['result'], 'prepare result');
  final programId = result['programId'];
  if (programId is! String || programId.isEmpty) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'prepare result.programId must be a non-empty string',
    );
  }
  return programId;
}

void decodeAck(String raw) {
  _response(raw);
}

CelRuntimeInfo decodeCreatedRuntime(String raw) {
  final value = _decode(raw);
  final object = _object(value, 'create result');
  if (object['ok'] == false) {
    throw _bridgeError(object['error']);
  }
  return decodeRuntimeInfo(raw);
}

List<CelBatchResult> decodeBatch(String raw) {
  final response = _response(raw);
  final result = response['result'];
  if (result is! List) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'batch result must be a list',
    );
  }
  return [for (final item in result) _decodeBatchItem(item)];
}

CelBatchResult _decodeBatchItem(Object? json) {
  final response = _object(json, 'batch item');
  if (response['protocolVersion'] != wireProtocolVersion) {
    throw CelBridgeException(
      code: 'protocol_mismatch',
      message: 'unexpected protocol version ${response['protocolVersion']}',
    );
  }
  final ok = response['ok'];
  if (ok is! bool) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'batch item.ok must be a boolean',
    );
  }
  if (!ok) {
    return CelBatchFailure(_bridgeError(response['error']));
  }
  return CelBatchSuccess(
    _decodeResult('batch item', () => CelValue.fromJson(response['result'])),
  );
}

CelRuntimeInfo decodeRuntimeInfo(String raw) {
  final value = _decode(raw);
  final info = _decodeResult(
    'runtime info',
    () => CelRuntimeInfo.fromJson(value),
  );
  if (info.protocolVersion != wireProtocolVersion) {
    throw CelBridgeException(
      code: 'protocol_mismatch',
      message:
          'expected protocol $wireProtocolVersion, got ${info.protocolVersion}',
    );
  }
  if (info.runtimeVersion != packageVersion) {
    throw CelBridgeException(
      code: 'runtime_mismatch',
      message: 'expected runtime $packageVersion, got ${info.runtimeVersion}',
    );
  }
  return info;
}

Map<String, Object?> _response(String raw) {
  final value = _decode(raw);
  final response = _object(value, 'response');
  if (response['protocolVersion'] != wireProtocolVersion) {
    throw CelBridgeException(
      code: 'protocol_mismatch',
      message: 'unexpected protocol version ${response['protocolVersion']}',
    );
  }
  final ok = response['ok'];
  if (ok is! bool) {
    throw const CelBridgeException(
      code: 'protocol_mismatch',
      message: 'response.ok must be a boolean',
    );
  }
  if (!ok) {
    throw _bridgeError(response['error']);
  }
  return response;
}

T _decodeResult<T>(String name, T Function() decode) {
  try {
    return decode();
  } on CelBridgeException {
    rethrow;
  } on FormatException catch (error) {
    throw CelBridgeException(
      code: 'protocol_mismatch',
      message: 'malformed $name: $error',
    );
  }
}

CelBridgeException _bridgeError(Object? json) {
  try {
    return CelBridgeException.fromJson(json);
  } on FormatException catch (error) {
    return CelBridgeException(
      code: 'protocol_mismatch',
      message: 'malformed bridge error: $error',
    );
  }
}

Object? _decode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException catch (error) {
    throw CelBridgeException(
      code: 'protocol_mismatch',
      message: 'malformed JSON: $error',
    );
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw CelBridgeException(
    code: 'protocol_mismatch',
    message: '$name must be an object',
  );
}
