import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('resource limits can override a safe profile', () async {
    final runtime = await CelRuntime.initialize(
      options: const CelRuntimeOptions(
        profile: 'safe',
        limits: CelRuntimeLimits(
          maxCompiledPrograms: 256,
          maxBatchExpressions: 64,
          maxPreparedPrograms: 128,
        ),
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime.info.limits['maxCompiledPrograms'], 256);
    expect(runtime.info.limits['maxBatchSize'], 64);
    expect(runtime.info.limits['maxPreparedPrograms'], 128);
    expect(runtime.info.features['configurableLimits'], isTrue);
  });
}
