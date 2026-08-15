final class CelRuntimeInfo {
  const CelRuntimeInfo({
    required this.protocolVersion,
    required this.runtimeVersion,
    required this.celGoVersion,
    required this.features,
  });

  factory CelRuntimeInfo.fromJson(Object? json) {
    final value = _object(json, 'runtime info');
    final features = value['features'];
    if (features is! Map) {
      throw const FormatException('runtime info.features must be an object');
    }
    return CelRuntimeInfo(
      protocolVersion: _int(value['protocolVersion'], 'protocolVersion'),
      runtimeVersion: _string(value['runtimeVersion'], 'runtimeVersion'),
      celGoVersion: _string(value['celGoVersion'], 'celGoVersion'),
      features: {
        for (final entry in features.entries)
          entry.key.toString(): entry.value == true,
      },
    );
  }

  final int protocolVersion;
  final String runtimeVersion;
  final String celGoVersion;
  final Map<String, bool> features;
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('$name must be an object');
}

String _string(Object? value, String name) {
  if (value is String) {
    return value;
  }
  throw FormatException('$name must be a string');
}

int _int(Object? value, String name) {
  if (value is int) {
    return value;
  }
  throw FormatException('$name must be an integer');
}
