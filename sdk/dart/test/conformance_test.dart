import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('matches shared conformance cases', () async {
    final raw = await File(
      '../../protocol/testdata/conformance_cases.json',
    ).readAsString();
    final cases = jsonDecode(raw) as List;
    final runtime = await CelRuntime.initialize();

    for (final item in cases) {
      final value = await runtime.evaluate(
        environment: Map<String, Object?>.from(item['environment'] as Map),
        source: item['source'] as String,
        variables: _fixtureVariables(item['variables'] as Map),
      );
      expect(value.toJson(), item['expected'], reason: item['name'] as String);
    }
  });
}

Map<String, Object?> _fixtureVariables(Map raw) => {
  for (final entry in raw.entries)
    entry.key as String: _fixtureValue(entry.value),
};

Object? _fixtureValue(Object? value) {
  if (value is List) return [for (final item in value) _fixtureValue(item)];
  if (value is Map) {
    if (value[r'$cel_bridge'] == true) return CelValue.fromJson(value);
    return {
      for (final entry in value.entries)
        entry.key as String: _fixtureValue(entry.value),
    };
  }
  return value;
}
