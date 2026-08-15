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
  });

  test('rejects non-string JSON map keys instead of dropping them', () {
    expect(
      () => encodeVariables({
        'values': {1: 'one'},
      }),
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
}
