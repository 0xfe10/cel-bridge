import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
  },
};

void main() {
  test('runs the native runtime through the public Dart API', () async {
    final runtime = await CelRuntime.initialize();
    expect(runtime.info.protocolVersion, 1);
    expect(runtime.info.runtimeVersion, '0.1.0');

    final validation = await runtime.validate(
      environment: _environment,
      source: 'age >= 18',
    );
    expect(validation.valid, isTrue);

    final value = await runtime.evaluate(
      environment: _environment,
      source: 'age >= 18',
      variables: {'age': 20},
    );
    expect((value as CelBoolValue).value, isTrue);
  });

  test('rejects NUL characters before the C ABI boundary', () async {
    final runtime = await CelRuntime.initialize();
    expect(
      () => runtime.validate(
        environment: _environment,
        source: 'age\u0000 >= 18',
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
}
