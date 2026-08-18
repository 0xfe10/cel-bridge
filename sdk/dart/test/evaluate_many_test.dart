import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
  },
};

void main() {
  test('returns empty results for an empty batch', () async {
    final runtime = await CelRuntime.initialize();
    expect(
      await runtime.evaluateMany(
        environment: _environment,
        sources: const [],
        variables: {'age': 20},
      ),
      isEmpty,
    );
  });

  test('rejects more than 256 expressions', () async {
    final runtime = await CelRuntime.initialize();
    expect(
      () => runtime.evaluateMany(
        environment: _environment,
        sources: List<String>.filled(257, 'true'),
        variables: {'age': 20},
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (error) => error.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('preserves order and partial failures', () async {
    final runtime = await CelRuntime.initialize();
    final results = await runtime.evaluateMany(
      environment: _environment,
      sources: const ['age >= 18', 'missing == 1', 'age >= 21'],
      variables: {'age': 20},
    );
    expect(results, hasLength(3));
    expect(results[0], isA<CelBatchSuccess>());
    expect(
      ((results[0] as CelBatchSuccess).value as CelBoolValue).value,
      isTrue,
    );
    expect((results[1] as CelBatchFailure).error.code, 'compile_error');
    expect(results[2], isA<CelBatchSuccess>());
  });

  test('matches evaluate for a single successful expression', () async {
    final runtime = await CelRuntime.initialize();
    const source = 'age >= 18';
    final single = await runtime.evaluate(
      environment: _environment,
      source: source,
      variables: {'age': 20},
    );
    final batch = await runtime.evaluateMany(
      environment: _environment,
      sources: const [source],
      variables: {'age': 20},
    );
    expect(batch, hasLength(1));
    expect((batch.single as CelBatchSuccess).value.toJson(), single.toJson());
  });

  test('evaluates thirty expressions', () async {
    final runtime = await CelRuntime.initialize();
    final sources = [for (var i = 0; i < 30; i++) 'age >= $i'];
    final results = await runtime.evaluateMany(
      environment: _environment,
      sources: sources,
      variables: {'age': 20},
    );
    expect(results, hasLength(30));
    for (var i = 0; i < results.length; i++) {
      expect(results[i], isA<CelBatchSuccess>(), reason: sources[i]);
      expect(
        ((results[i] as CelBatchSuccess).value as CelBoolValue).value,
        20 >= i,
      );
    }
  });
}
