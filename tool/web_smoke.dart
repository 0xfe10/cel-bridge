import 'package:cel_bridge/cel_bridge.dart';
import 'package:web/web.dart' as web;

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
  },
};

Future<void> main() async {
  final output = web.document.querySelector('#output') as web.HTMLPreElement;
  try {
    final runtime = await CelRuntime.initialize(
      options: const CelRuntimeOptions(
        wasmUrl: '/cel_bridge.wasm',
        wasmExecUrl: '/wasm_exec.js',
        wasmIntegrity: null,
        wasmExecIntegrity: null,
      ),
    );
    final validation = await runtime.validate(
      environment: _environment,
      source: 'age >= 18',
    );
    final value = await runtime.evaluate(
      environment: _environment,
      source: 'age >= 18',
      variables: {'age': 20},
    );
    output.textContent =
        '${runtime.info.runtimeVersion}|${validation.valid}|'
        '${(value as CelBoolValue).value}';
    output.dataset['ready'] = 'true';
  } catch (error) {
    output.textContent = '$error';
    output.dataset['error'] = 'true';
  }
}
