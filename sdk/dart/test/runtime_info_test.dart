import 'package:cel_bridge/cel_bridge.dart';
import 'package:cel_bridge/src/wire/decoder.dart';
import 'package:test/test.dart';

void main() {
  test('accepts matching runtime and protocol versions', () {
    final info = decodeRuntimeInfo(
      '{"protocolVersion":1,"runtimeVersion":"0.3.1",'
      '"celGoVersion":"v0.31.0","features":{"costLimit":true}}',
    );
    expect(info.runtimeVersion, packageVersion);
    expect(info.protocolVersion, wireProtocolVersion);
    expect(info.features['costLimit'], isTrue);
  });

  test('rejects runtime version mismatches', () {
    expect(
      () => decodeRuntimeInfo(
        '{"protocolVersion":1,"runtimeVersion":"0.1.0",'
        '"celGoVersion":"v0.31.0","features":{}}',
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (e) => e.code,
          'code',
          'runtime_mismatch',
        ),
      ),
    );
  });

  test('rejects non-boolean feature flags', () {
    expect(
      () => decodeRuntimeInfo(
        '{"protocolVersion":1,"runtimeVersion":"0.3.1",'
        '"celGoVersion":"v0.31.0","features":{"costLimit":"true"}}',
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (e) => e.code,
          'code',
          'protocol_mismatch',
        ),
      ),
    );
  });
}
