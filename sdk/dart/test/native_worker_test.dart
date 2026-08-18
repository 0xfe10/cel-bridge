import 'package:cel_bridge/cel_bridge.dart';
import 'package:cel_bridge/src/backend/ffi/native_worker.dart';
import 'package:test/test.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
  },
};

void main() {
  test('reuses one native worker across many calls', () async {
    final runtime = await CelRuntime.initialize();
    final before = nativeWorkerSpawnCountForTesting();
    for (var i = 0; i < 32; i++) {
      final value = await runtime.evaluate(
        environment: _environment,
        source: 'age >= 18',
        variables: {'age': i},
      );
      expect((value as CelBoolValue).value, i >= 18);
    }
    expect(nativeWorkerSpawnCountForTesting(), before);
  });

  test('returns concurrent requests without mixing results', () async {
    final runtime = await CelRuntime.initialize();
    final results = await Future.wait([
      for (var i = 0; i < 30; i++)
        runtime.evaluate(
          environment: _environment,
          source: 'age >= 18',
          variables: {'age': i},
        ),
    ]);
    for (var i = 0; i < results.length; i++) {
      expect((results[i] as CelBoolValue).value, i >= 18, reason: 'age=$i');
    }
  });

  test('rebuilds the worker after an exit', () async {
    final runtime = await CelRuntime.initialize();
    final before = nativeWorkerSpawnCountForTesting();
    await closeNativeWorkerForTesting();
    final value = await runtime.evaluate(
      environment: _environment,
      source: 'age >= 18',
      variables: {'age': 20},
    );
    expect((value as CelBoolValue).value, isTrue);
    expect(nativeWorkerSpawnCountForTesting(), before + 1);
  });
}
