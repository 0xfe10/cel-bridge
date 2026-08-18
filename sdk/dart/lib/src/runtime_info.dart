final class CelRuntimeInfo {
  const CelRuntimeInfo({
    required this.protocolVersion,
    required this.runtimeVersion,
    required this.celGoVersion,
    required this.features,
    this.abiVersion,
    this.profiles = const [],
    this.limits = const {},
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
          entry.key.toString(): _bool(
            entry.value,
            'runtime info.features.${entry.key}',
          ),
      },
      abiVersion: value.containsKey('abiVersion')
          ? _int(value['abiVersion'], 'abiVersion')
          : null,
      profiles: _stringList(value['profiles'], 'profiles'),
      limits: _intMap(value['limits'], 'limits'),
    );
  }

  final int protocolVersion;
  final String runtimeVersion;
  final String celGoVersion;
  final Map<String, bool> features;
  final int? abiVersion;
  final List<String> profiles;
  final Map<String, int> limits;
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

bool _bool(Object? value, String name) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$name must be a boolean');
}

List<String> _stringList(Object? value, String name) {
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FormatException('$name must be a list');
  }
  return [for (final item in value) _string(item, '$name item')];
}

Map<String, int> _intMap(Object? value, String name) {
  if (value == null) {
    return const {};
  }
  if (value is! Map) {
    throw FormatException('$name must be an object');
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): _int(entry.value, '$name.${entry.key}'),
  };
}
