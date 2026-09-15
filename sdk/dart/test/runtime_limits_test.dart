import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('resource limits can override a safe profile', () async {
    final runtime = await CelRuntime.initialize(
      options: const CelRuntimeOptions(
        profile: 'safe',
        limits: CelRuntimeLimits(
          maxCompiledPrograms: 256,
          maxBatchExpressions: 300,
          maxPreparedPrograms: 128,
        ),
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime.info.limits['maxCompiledPrograms'], 256);
    expect(runtime.info.limits['maxBatchSize'], 300);
    expect(runtime.info.limits['maxPreparedPrograms'], 128);
    expect(runtime.info.features['configurableLimits'], isTrue);

    final results = await runtime.evaluateMany(
      environment: const {'schemaVersion': 1, 'variables': <String, Object?>{}},
      sources: List.filled(257, 'true'),
      variables: const {},
    );
    expect(results, hasLength(257));
  });
}
