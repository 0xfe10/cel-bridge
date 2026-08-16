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
    try {
      await CelRuntime.initialize(
        options: const CelRuntimeOptions(
          wasmUrl: '/missing-cel-bridge.wasm',
          wasmExecUrl: '/wasm_exec.js',
          wasmIntegrity: null,
          wasmExecIntegrity: null,
        ),
      );
    } on CelBridgeException {
      // The second initialize call must be allowed to recover.
    } on Object {
      // Keep the fixture independent of the platform's error wrapper.
    }
    final runtime = await CelRuntime.initialize(
      options: const CelRuntimeOptions(
        wasmUrl: '/cel_bridge.wasm',
        wasmExecUrl: '/wasm_exec.js',
        wasmIntegrity: null,
        wasmExecIntegrity: null,
      ),
    );
    final value = await runtime.evaluate(
      environment: _environment,
      source: 'age >= 18',
      variables: {'age': 20},
    );
    output.textContent =
        'retry|${runtime.info.runtimeVersion}|${(value as CelBoolValue).value}';
    output.dataset['ready'] = 'true';
  } catch (error) {
    output.textContent = '$error';
    output.dataset['error'] = 'true';
  }
}
