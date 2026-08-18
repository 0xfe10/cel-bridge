import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('matches shared evaluateRequests cases', () async {
    final raw = await File(
      '../../protocol/testdata/evaluate_requests_cases.json',
    ).readAsString();
    final cases = jsonDecode(raw) as List;
    final runtime = await CelRuntime.initialize();

    for (final item in cases) {
      final name = item['name'] as String;
      final environment = Map<String, Object?>.from(item['environment'] as Map);
      final requests = [
        for (final request in item['requests'] as List)
          CelEvaluationRequest(
            id: request['id'] as String,
            source: request['source'] as String?,
            programId: request['programId'] as String?,
            variables: _fixtureVariables(
              (request['variables'] as Map?) ?? const {},
            ),
            expectedResultType: request['expectedResultType'],
          ),
      ];
      if (item['ok'] == false) {
        try {
          await runtime.evaluateRequests(
            environment: environment,
            requests: requests,
          );
          fail('expected ${item['expectedCode']} for $name');
        } on CelBridgeException catch (error) {
          expect(error.code, item['expectedCode'], reason: name);
        }
        continue;
      }

      final results = await runtime.evaluateRequests(
        environment: environment,
        requests: requests,
      );
      final expected = item['results'] as List;
      expect(results, hasLength(expected.length), reason: name);
      for (var i = 0; i < expected.length; i++) {
        final want = expected[i] as Map;
        final got = results[i];
        expect(got.id, want['id'], reason: '$name [$i]');
        if (want['ok'] == false) {
          expect(got, isA<CelRequestFailure>(), reason: '$name [$i]');
          expect(
            (got as CelRequestFailure).error.code,
            want['expectedCode'],
            reason: '$name [$i]',
          );
          continue;
        }
        expect(got, isA<CelRequestSuccess>(), reason: '$name [$i]');
        expect(
          (got as CelRequestSuccess).value.toJson(),
          want['expected'],
          reason: '$name [$i]',
        );
      }
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
