import 'dart:convert';
import 'dart:typed_data';

import '../cel_value.dart';

final _maxCelInt = BigInt.parse('9223372036854775807');
const _taggedValueMarker = r'$cel_bridge';
const _maxValueDepth = 32;

String encodeEnvironment(Map<String, Object?> environment) {
  return jsonEncode(_jsonObject(environment, 'environment'));
}

String encodeVariables(Map<String, Object?> variables) {
  return jsonEncode(_jsonObject(variables, 'variables', valueDepth: 1));
}

Object? _jsonValue(Object? value, [int depth = 0]) {
  if (depth > _maxValueDepth) {
    throw ArgumentError('value nesting exceeds $_maxValueDepth levels');
  }
  if (value is CelValue) return _tagCelValue(value, depth);
  if (value is BigInt) {
    final kind = value.isNegative || value <= _maxCelInt ? 'int' : 'uint';
    return _tag({'kind': kind, 'value': value.toString()});
  }
  if (value is Uint8List) {
    return _tag({'kind': 'bytes', 'value': base64Encode(value)});
  }
  if (value is DateTime) return _tag(CelTimestampValue(value).toJson());
  if (value is CelDurationValue) return _tag(value.toJson());
  if (value is List) {
    return [for (final item in value) _jsonValue(item, depth + 1)];
  }
  if (value is Map) {
    if (value.keys.contains(_taggedValueMarker)) return _tagMap(value, depth);
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('map keys must be strings in JSON variables');
      }
      result[entry.key as String] = _jsonValue(entry.value, depth + 1);
    }
    return result;
  }
  if (value == null || value is bool || value is String) return value;
  if (value is double) {
    return value.isFinite
        ? value
        : _tag({'kind': 'double', 'value': _formatDouble(value)});
  }
  if (value is int) return value;
  throw ArgumentError('unsupported JSON value ${value.runtimeType}');
}

Map<String, Object?> _tag(Map<String, Object?> value) => {
  _taggedValueMarker: true,
  ...value,
};

Map<String, Object?> _tagCelValue(CelValue value, int depth) {
  if (value is CelListValue) {
    return _tag({
      'kind': 'list',
      'items': [for (final item in value.values) _jsonValue(item, depth + 1)],
    });
  }
  if (value is CelMapValue) {
    return _tag({
      'kind': 'map',
      'entries': [
        for (final entry in value.entries)
          {
            'key': _jsonValue(entry.key, depth + 1),
            'value': _jsonValue(entry.value, depth + 1),
          },
      ],
    });
  }
  return _tag(value.toJson());
}

Map<String, Object?> _tagMap(Map value, int depth) {
  final entries = <Map<String, Object?>>[];
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw ArgumentError('map keys must be strings in JSON variables');
    }
    entries.add({
      'key': entry.key as String,
      'value': _jsonValue(entry.value, depth + 1),
    });
  }
  return _tag({'kind': 'map', 'entries': entries});
}

String _formatDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  return value.toString();
}

Map<String, Object?> _jsonObject(
  Map<String, Object?> value,
  String name, {
  int valueDepth = 0,
}) {
  try {
    return {
      for (final entry in value.entries)
        entry.key: _jsonValue(entry.value, valueDepth),
    };
  } on ArgumentError catch (error) {
    throw ArgumentError('$name: $error');
  }
}
