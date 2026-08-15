import 'package:cel_bridge/cel_bridge.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {'age': {'type': 'int'}},
};

Future<void> main() async {
  final runtime = await CelRuntime.initialize();
  final value = await runtime.evaluate(
    environment: _environment,
    source: 'age >= 18',
    variables: {'age': 20},
  );
  if (runtime.info.runtimeVersion != packageVersion ||
      value is! CelBoolValue ||
      !value.value) {
    throw StateError('release consumer smoke returned an unexpected result');
  }
  print('release consumer: ${runtime.info.runtimeVersion} / ${value.value}');
}
