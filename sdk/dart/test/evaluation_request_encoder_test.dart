import 'dart:convert';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:cel_bridge/src/wire/encoder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'hoists arbitrary equal top-level variables without business knowledge',
    () {
      final batches = encodeEvaluationRequestBatches(
        const [
          CelEvaluationRequest(
            id: 'one',
            source: 'value > 0',
            variables: {
              'context': {'region': 'north'},
              'value': 1,
            },
          ),
          CelEvaluationRequest(
            id: 'two',
            source: 'value > 0',
            variables: {
              'value': 2,
              'context': {'region': 'north'},
            },
          ),
        ],
        maxRequestCount: 10,
        maxRequestBytes: 4096,
        maxSourceBytes: 4096,
      );

      expect(batches, hasLength(1));
      final envelope =
          jsonDecode(batches.single.payload) as Map<String, Object?>;
      expect(envelope['sharedVariables'], {
        'context': {'region': 'north'},
      });
      final requests = envelope['requests'] as List;
      expect((requests[0] as Map)['variables'], {'value': 1});
      expect((requests[1] as Map)['variables'], {'value': 2});
    },
  );

  test('splits a logical request list by runtime batch count', () {
    final batches = encodeEvaluationRequestBatches(
      [
        for (var index = 0; index < 5; index++)
          CelEvaluationRequest(
            id: '$index',
            source: 'value == $index',
            variables: {'value': index},
          ),
      ],
      maxRequestCount: 2,
      maxRequestBytes: 4096,
      maxSourceBytes: 4096,
    );

    expect(batches.map((batch) => batch.requestCount), [2, 2, 1]);
    for (final batch in batches) {
      expect(utf8.encode(batch.payload).length, lessThanOrEqualTo(4096));
    }
  });

  test('does not hoist numerically equal values with different JSON types', () {
    final batches = encodeEvaluationRequestBatches(
      const [
        CelEvaluationRequest(
          id: 'integer',
          source: 'value == 1',
          variables: {
            'value': 1,
            'nested': {'value': 1},
          },
        ),
        CelEvaluationRequest(
          id: 'double',
          source: 'value == 1.0',
          variables: {
            'value': 1.0,
            'nested': {'value': 1.0},
          },
        ),
      ],
      maxRequestCount: 10,
      maxRequestBytes: 4096,
      maxSourceBytes: 4096,
    );

    final envelope = jsonDecode(batches.single.payload) as Map<String, Object?>;
    expect(envelope['sharedVariables'], isEmpty);
    final requests = envelope['requests'] as List;
    expect((requests[0] as Map)['variables'], {
      'value': 1,
      'nested': {'value': 1},
    });
    expect((requests[1] as Map)['variables'], {
      'value': 1.0,
      'nested': {'value': 1.0},
    });
  });
}
