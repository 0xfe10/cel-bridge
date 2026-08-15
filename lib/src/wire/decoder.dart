import 'dart:convert';

import '../cel_exception.dart';
import '../cel_validation_result.dart';
import '../cel_value.dart';
import '../runtime_info.dart';
import '../cel_runtime_options.dart';

CelValidationResult decodeValidation(String raw) {
  final response = _response(raw);
  if (response['ok'] != true) {
    throw CelBridgeException.fromJson(response['error']);
  }
  return CelValidationResult.fromJson(response['result']);
}

CelValue decodeEvaluation(String raw) {
  final response = _response(raw);
  if (response['ok'] != true) {
    throw CelBridgeException.fromJson(response['error']);
  }
  return CelValue.fromJson(response['result']);
}

CelRuntimeInfo decodeRuntimeInfo(String raw) {
  final value = _decode(raw);
  final info = CelRuntimeInfo.fromJson(value);
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
  return response;
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
