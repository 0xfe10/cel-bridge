import 'dart:typed_data';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('round trips every tagged CEL value', () {
    final values = <CelValue>[
      const CelNullValue(),
      const CelBoolValue(true),
      CelIntValue(BigInt.parse('9223372036854775807')),
      CelUintValue(BigInt.parse('18446744073709551615')),
      const CelDoubleValue(double.nan),
      const CelStringValue('hello'),
      CelBytesValue(Uint8List.fromList([1, 2, 3])),
      CelTimestampValue(DateTime.utc(2026, 8, 15, 10)),
      const CelDurationValue(seconds: -1, nanoseconds: -500000000),
      const CelListValue([CelBoolValue(false), CelNullValue()]),
      CelMapValue([
        CelMapEntry(CelStringValue('key'), CelIntValue(BigInt.from(7))),
      ]),
    ];

    for (final value in values) {
      final decoded = CelValue.fromJson(value.toJson());
      expect(decoded.toJson(), value.toJson());
    }
  });

  test('parses signed durations without invalid component signs', () {
    final halfSecond = CelDurationValue.parse('-0.5s');
    expect(halfSecond.seconds, 0);
    expect(halfSecond.nanoseconds, -500000000);
    expect(halfSecond.toJson()['value'], '-0.500000000s');

    final oneAndHalfSeconds = CelDurationValue.parse('-1.5s');
    expect(oneAndHalfSeconds.seconds, -1);
    expect(oneAndHalfSeconds.nanoseconds, -500000000);
  });

  test('rejects unsupported tagged values', () {
    expect(
      () => CelValue.fromJson({'kind': 'not-a-cel-kind'}),
      throwsFormatException,
    );
  });
}
