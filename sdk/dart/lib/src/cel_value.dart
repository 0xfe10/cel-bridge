import 'dart:convert';
import 'dart:typed_data';

sealed class CelValue {
  const CelValue();

  factory CelValue.fromJson(Object? json) {
    final value = _object(json, 'CEL value');
    switch (value['kind']) {
      case 'null':
        return const CelNullValue();
      case 'bool':
        return CelBoolValue(_bool(value['value'], 'bool.value'));
      case 'int':
        return CelIntValue(BigInt.parse(_string(value['value'], 'int.value')));
      case 'uint':
        return CelUintValue(
          BigInt.parse(_string(value['value'], 'uint.value')),
        );
      case 'double':
        return CelDoubleValue(
          _parseDouble(_string(value['value'], 'double.value')),
        );
      case 'string':
        return CelStringValue(_string(value['value'], 'string.value'));
      case 'bytes':
        return CelBytesValue(
          base64Decode(_string(value['value'], 'bytes.value')),
        );
      case 'timestamp':
        return CelTimestampValue(
          DateTime.parse(_string(value['value'], 'timestamp.value')).toUtc(),
        );
      case 'duration':
        return CelDurationValue.parse(
          _string(value['value'], 'duration.value'),
        );
      case 'list':
        final items = value['items'];
        if (items is! List) {
          throw const FormatException('list.items must be a list');
        }
        return CelListValue([
          for (final item in items) CelValue.fromJson(item),
        ]);
      case 'map':
        final entries = value['entries'];
        if (entries is! List) {
          throw const FormatException('map.entries must be a list');
        }
        return CelMapValue([for (final entry in entries) _mapEntry(entry)]);
      default:
        throw FormatException('unsupported CEL value kind ${value['kind']}');
    }
  }

  Map<String, Object?> toJson();
}

final class CelNullValue extends CelValue {
  const CelNullValue();

  @override
  Map<String, Object?> toJson() => {'kind': 'null'};
}

final class CelBoolValue extends CelValue {
  const CelBoolValue(this.value);
  final bool value;

  @override
  Map<String, Object?> toJson() => {'kind': 'bool', 'value': value};
}

final class CelIntValue extends CelValue {
  const CelIntValue(this.value);
  final BigInt value;

  @override
  Map<String, Object?> toJson() => {'kind': 'int', 'value': value.toString()};
}

final class CelUintValue extends CelValue {
  const CelUintValue(this.value);
  final BigInt value;

  @override
  Map<String, Object?> toJson() => {'kind': 'uint', 'value': value.toString()};
}

final class CelDoubleValue extends CelValue {
  const CelDoubleValue(this.value);
  final double value;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'double',
    'value': _formatDouble(value),
  };
}

final class CelStringValue extends CelValue {
  const CelStringValue(this.value);
  final String value;

  @override
  Map<String, Object?> toJson() => {'kind': 'string', 'value': value};
}

final class CelBytesValue extends CelValue {
  CelBytesValue(List<int> value) : value = Uint8List.fromList(value);
  final Uint8List value;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'bytes',
    'value': base64Encode(value),
  };
}

final class CelTimestampValue extends CelValue {
  CelTimestampValue(DateTime value) : value = value.toUtc();
  final DateTime value;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'timestamp',
    'value': _formatTimestamp(value),
  };
}

final class CelDurationValue extends CelValue {
  const CelDurationValue({required this.seconds, required this.nanoseconds});

  factory CelDurationValue.parse(String value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,9}))?s$').firstMatch(value);
    if (match == null) throw FormatException('invalid CEL duration $value');
    final negative = match.group(1) == '-';
    final seconds = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(9, '0');
    final nanoseconds = int.parse(fraction);
    if (negative && (seconds != 0 || nanoseconds != 0)) {
      return CelDurationValue(
        seconds: -seconds,
        nanoseconds: nanoseconds == 0 ? 0 : -nanoseconds,
      );
    }
    return CelDurationValue(seconds: seconds, nanoseconds: nanoseconds);
  }

  final int seconds;
  final int nanoseconds;

  String toWire() {
    _validate();
    return _formatDuration(seconds, nanoseconds);
  }

  @override
  Map<String, Object?> toJson() {
    _validate();
    return {'kind': 'duration', 'value': _formatDuration(seconds, nanoseconds)};
  }

  void _validate() {
    if (nanoseconds <= -1000000000 || nanoseconds >= 1000000000) {
      throw ArgumentError.value(nanoseconds, 'nanoseconds');
    }
    if (seconds != 0 &&
        nanoseconds != 0 &&
        ((seconds < 0) != (nanoseconds < 0))) {
      throw ArgumentError('duration components must have matching signs');
    }
  }
}

final class CelListValue extends CelValue {
  const CelListValue(this.values);
  final List<CelValue> values;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'list',
    'items': [for (final value in values) value.toJson()],
  };
}

final class CelMapEntry {
  const CelMapEntry(this.key, this.value);
  final CelValue key;
  final CelValue value;
}

final class CelMapValue extends CelValue {
  const CelMapValue(this.entries);
  final List<CelMapEntry> entries;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'map',
    'entries': [
      for (final entry in entries)
        {'key': entry.key.toJson(), 'value': entry.value.toJson()},
    ],
  };
}

CelMapEntry _mapEntry(Object? json) {
  final value = _object(json, 'map entry');
  return CelMapEntry(
    CelValue.fromJson(value['key']),
    CelValue.fromJson(value['value']),
  );
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('$name must be an object');
}

String _string(Object? value, String name) {
  if (value is String) return value;
  throw FormatException('$name must be a string');
}

bool _bool(Object? value, String name) {
  if (value is bool) return value;
  throw FormatException('$name must be a boolean');
}

double _parseDouble(String value) => switch (value) {
  'NaN' => double.nan,
  'Infinity' || '+Infinity' => double.infinity,
  '-Infinity' => double.negativeInfinity,
  _ => double.parse(value),
};

String _formatDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  return value.toString();
}

String _formatDuration(int seconds, int nanoseconds) {
  final negative = seconds < 0 || nanoseconds < 0;
  final wholeSeconds = seconds.abs();
  final fraction = nanoseconds.abs().toString().padLeft(9, '0');
  if (nanoseconds == 0) return '${negative ? '-' : ''}${wholeSeconds}s';
  return '${negative ? '-' : ''}$wholeSeconds.$fraction'
      's';
}

String _formatTimestamp(DateTime value) {
  final iso = value.toUtc().toIso8601String();
  final dot = iso.indexOf('.');
  if (dot == -1) return iso;
  final suffix = iso.endsWith('Z') ? 'Z' : '';
  final fractionEnd = suffix.isEmpty ? iso.length : iso.length - 1;
  final fraction = iso
      .substring(dot + 1, fractionEnd)
      .replaceFirst(RegExp(r'0+$'), '');
  return '${iso.substring(0, dot)}${fraction.isEmpty ? '' : '.$fraction'}$suffix';
}
