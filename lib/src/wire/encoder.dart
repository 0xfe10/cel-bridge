import 'dart:convert';
import 'dart:typed_data';

import '../cel_value.dart';

final _maxCelInt = BigInt.parse('9223372036854775807');

String encodeEnvironment(Map<String, Object?> environment) {
  return jsonEncode(_jsonObject(environment, 'environment'));
}

String encodeVariables(Map<String, Object?> variables) {
  return jsonEncode(_jsonObject(variables, 'variables'));
}

Object? _jsonValue(Object? value) {
  if (value is CelValue) return value.toJson();
  if (value is BigInt) {
    final kind = value.isNegative || value <= _maxCelInt ? 'int' : 'uint';
    return {'kind': kind, 'value': value.toString()};
  }
  if (value is Uint8List) {
    return {'kind': 'bytes', 'value': base64Encode(value)};
  }
  if (value is DateTime) {
    return {'kind': 'timestamp', 'value': value.toUtc().toIso8601String()};
  }
  if (value is CelDurationValue) return value.toJson();
  if (value is List) return [for (final item in value) _jsonValue(item)];
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: _jsonValue(entry.value),
    };
  }
  if (value == null || value is bool || value is String) return value;
  if (value is double) {
    return value.isFinite
        ? value
        : {'kind': 'double', 'value': _formatDouble(value)};
  }
  if (value is int) return value;
  throw ArgumentError('unsupported JSON value ${value.runtimeType}');
}

String _formatDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  return value.toString();
}

Map<String, Object?> _jsonObject(Map<String, Object?> value, String name) {
  try {
    return {
      for (final entry in value.entries) entry.key: _jsonValue(entry.value),
    };
  } on ArgumentError catch (error) {
    throw ArgumentError('$name: $error');
  }
}
