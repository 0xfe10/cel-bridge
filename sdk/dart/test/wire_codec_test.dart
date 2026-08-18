import 'dart:convert';
import 'dart:typed_data';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:cel_bridge/src/wire/decoder.dart';
import 'package:cel_bridge/src/wire/encoder.dart';
import 'package:test/test.dart';

void main() {
  test('encodes Dart variables as CEL-safe JSON', () {
    final encoded =
        jsonDecode(
              encodeVariables({
                'small': BigInt.from(4),
                'large': BigInt.parse('18446744073709551615'),
                'bytes': Uint8List.fromList([72, 105]),
                'notANumber': double.nan,
                'nested': [DateTime.utc(2026, 8, 15)],
                'celList': CelListValue([CelIntValue(BigInt.from(7))]),
                'celMap': CelMapValue([
                  CelMapEntry(
                    const CelStringValue('answer'),
                    CelIntValue(BigInt.from(7)),
                  ),
                ]),
                'markerMap': {r'$cel_bridge': true, 'kind': 'business'},
              }),
            )
            as Map<String, Object?>;

    expect(encoded['small'], {
      r'$cel_bridge': true,
      'kind': 'int',
      'value': '4',
    });
    expect(encoded['large'], {
      r'$cel_bridge': true,
      'kind': 'uint',
      'value': '18446744073709551615',
    });
    expect(encoded['bytes'], {
      r'$cel_bridge': true,
      'kind': 'bytes',
      'value': 'SGk=',
    });
    expect(encoded['notANumber'], {
      r'$cel_bridge': true,
      'kind': 'double',
      'value': 'NaN',
    });
    expect((encoded['nested'] as List).single, {
      r'$cel_bridge': true,
      'kind': 'timestamp',
      'value': '2026-08-15T00:00:00Z',
    });
    expect(encoded['celList'], {
      r'$cel_bridge': true,
      'kind': 'list',
      'items': [
        {r'$cel_bridge': true, 'kind': 'int', 'value': '7'},
      ],
    });
    expect(encoded['celMap'], {
      r'$cel_bridge': true,
      'kind': 'map',
      'entries': [
        {
          'key': {r'$cel_bridge': true, 'kind': 'string', 'value': 'answer'},
          'value': {r'$cel_bridge': true, 'kind': 'int', 'value': '7'},
        },
      ],
    });
    expect(encoded['markerMap'], {
      r'$cel_bridge': true,
      'kind': 'map',
      'entries': [
        {'key': r'$cel_bridge', 'value': true},
        {'key': 'kind', 'value': 'business'},
      ],
    });
  });

  test('rejects non-string JSON map keys instead of dropping them', () {
    expect(
      () => encodeVariables({
        'values': {1: 'one'},
      }),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects cyclic or overly deep input values', () {
    List<Object?> nested(int levels) {
      final value = <Object?>[];
      var current = value;
      for (var i = 0; i < levels; i++) {
        final next = <Object?>[];
        current.add(next);
        current = next;
      }
      return value;
    }

    expect(() => encodeVariables({'value': nested(31)}), returnsNormally);
    expect(
      () => encodeVariables({'value': nested(32)}),
      throwsA(isA<ArgumentError>()),
    );

    final cyclic = <Object?>[];
    cyclic.add(cyclic);
    expect(
      () => encodeVariables({'value': cyclic}),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('decodes successful validation and evaluation responses', () {
    const validation =
        '{"protocolVersion":1,"ok":true,"result":{"valid":false,"issues":['
        '{"severity":"error","code":"parse_error","message":"bad",'
        '"line":1,"column":2}]}}';
    final result = decodeValidation(validation);
    expect(result.valid, isFalse);
    expect(result.issues.single.column, 2);

    const evaluation =
        '{"protocolVersion":1,"ok":true,"result":{"kind":"int",'
        '"value":"7"}}';
    expect((decodeEvaluation(evaluation) as CelIntValue).value, BigInt.from(7));
  });

  test('maps malformed and mismatched responses to bridge errors', () {
    expect(
      () => decodeEvaluation('not json'),
      throwsA(
        isA<CelBridgeException>().having(
          (e) => e.code,
          'code',
          'protocol_mismatch',
        ),
      ),
    );
    expect(
      () => decodeEvaluation(
        '{"protocolVersion":2,"ok":true,"result":{"kind":"null"}}',
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

  test('decodes per-request batch and prepare acknowledgements', () {
    const batch =
        '{"protocolVersion":1,"ok":true,"result":['
        '{"id":"ok","ok":true,"result":{"kind":"bool","value":true}},'
        '{"id":"bad","ok":false,"error":{"code":"compile_error",'
        '"message":"nope","issues":[]}}]}';
    final results = decodeRequests(batch);
    expect(results, hasLength(2));
    expect(
      ((results[0] as CelRequestSuccess).value as CelBoolValue).value,
      isTrue,
    );
    expect((results[1] as CelRequestFailure).error.code, 'compile_error');

    expect(
      decodePrepare(
        '{"protocolVersion":1,"ok":true,"result":{"programId":"prg_1"}}',
      ),
      'prg_1',
    );
    decodeAck('{"protocolVersion":1,"ok":true,"result":{"released":true}}');
    expect(
      decodeCreatedRuntime(
        '{"protocolVersion":1,"runtimeVersion":"$packageVersion",'
        '"celGoVersion":"v0.31.0","features":{}}',
      ).runtimeVersion,
      packageVersion,
    );
    expect(
      () => decodeCreatedRuntime(
        '{"protocolVersion":1,"ok":false,"error":{"code":"invalid_request",'
        '"message":"bad","issues":[]}}',
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (e) => e.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('rejects malformed boolean response fields as protocol errors', () {
    for (final decode in [
      () => decodeEvaluation(
        '{"protocolVersion":1,"ok":true,"result":{"kind":"bool",'
        '"value":"true"}}',
      ),
      () => decodeValidation(
        '{"protocolVersion":1,"ok":true,"result":{"valid":"true",'
        '"issues":[]}}',
      ),
      () => decodeEvaluation(
        '{"protocolVersion":1,"ok":"true","result":{"kind":"null"}}',
      ),
    ]) {
      expect(
        decode,
        throwsA(
          isA<CelBridgeException>().having(
            (e) => e.code,
            'code',
            'protocol_mismatch',
          ),
        ),
      );
    }
  });
}
