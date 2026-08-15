import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('matches shared conformance cases', () async {
    final raw = await File('testdata/conformance_cases.json').readAsString();
    final cases = jsonDecode(raw) as List;
    final runtime = await CelRuntime.initialize();

    for (final item in cases) {
      final value = await runtime.evaluate(
        environment: Map<String, Object?>.from(item['environment'] as Map),
        source: item['source'] as String,
        variables: Map<String, Object?>.from(item['variables'] as Map),
      );
      expect(value.toJson(), item['expected'], reason: item['name'] as String);
    }
  });
}
