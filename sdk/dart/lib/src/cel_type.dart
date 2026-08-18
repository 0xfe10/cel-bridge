/// Stable, cross-SDK CEL type encoding used for `resultType` and
/// `expectedResultType`. Nested list/map types use [element], [key], and
/// [value].
final class CelType {
  const CelType({required this.type, this.element, this.key, this.value});

  factory CelType.fromJson(Object? json) {
    if (json is String) {
      return CelType(type: json);
    }
    final value = _object(json, 'CEL type');
    return CelType(
      type: _string(value['type'], 'CEL type.type'),
      element: value['element'] == null
          ? null
          : CelType.fromJson(value['element']),
      key: value['key'] == null ? null : CelType.fromJson(value['key']),
      value: value['value'] == null ? null : CelType.fromJson(value['value']),
    );
  }

  static const nullType = CelType(type: 'null');
  static const boolType = CelType(type: 'bool');
  static const intType = CelType(type: 'int');
  static const uintType = CelType(type: 'uint');
  static const doubleType = CelType(type: 'double');
  static const stringType = CelType(type: 'string');
  static const bytesType = CelType(type: 'bytes');
  static const timestampType = CelType(type: 'timestamp');
  static const durationType = CelType(type: 'duration');
  static const dynType = CelType(type: 'dyn');

  static CelType list(CelType element) =>
      CelType(type: 'list', element: element);

  static CelType map(CelType key, CelType value) =>
      CelType(type: 'map', key: key, value: value);

  final String type;
  final CelType? element;
  final CelType? key;
  final CelType? value;

  Map<String, Object?> toJson() => {
    'type': type,
    if (element != null) 'element': element!.toJson(),
    if (key != null) 'key': key!.toJson(),
    if (value != null) 'value': value!.toJson(),
  };

  Object toExpectedJson() {
    if (element == null && key == null && value == null) {
      return type;
    }
    return toJson();
  }

  @override
  bool operator ==(Object other) {
    return other is CelType &&
        other.type == type &&
        other.element == element &&
        other.key == key &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(type, element, key, value);
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('$name must be an object or type name');
}

String _string(Object? value, String name) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$name must be a non-empty string');
}
