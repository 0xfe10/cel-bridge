import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
    'country': {'type': 'string'},
  },
};

Future<void> main() async {
  try {
    final runtime = await CelRuntime.initialize();
    final source = 'age >= 18 && country in ["CN", "SG"]';
    final validation = await runtime.validate(
      environment: _environment,
      source: source,
    );
    final result = await runtime.evaluate(
      environment: _environment,
      source: source,
      variables: {'age': 20, 'country': 'CN'},
    );
    print('runtime: ${runtime.info.runtimeVersion}');
    print('validation: ${validation.valid ? 'valid' : 'invalid'}');
    print('result: ${_result(result)}');
  } on CelBridgeException catch (error) {
    print('error: ${error.code}: ${error.message}');
    exitCode = 1;
  }
}

String _result(CelValue value) => switch (value) {
  CelBoolValue(:final value) => value.toString(),
  _ => value.toJson().toString(),
};
