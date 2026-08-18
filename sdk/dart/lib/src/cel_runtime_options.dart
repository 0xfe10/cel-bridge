const packageVersion = '0.4.1';
const wireProtocolVersion = 1;
const _defaultWasmIntegrity =
    'sha256-44qu0kT2bvY+7JHXPWOYJ6veeP9MNI5XwdIwobazcyk=';
const _defaultWasmExecIntegrity =
    'sha256-DJSfSZb5qJaY5LXFht4yJJw7abe6rbZNIgBzzASsuhQ=';

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.4.1/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.4.1/wasm_exec.js',
    this.wasmIntegrity = _defaultWasmIntegrity,
    this.wasmExecIntegrity = _defaultWasmExecIntegrity,
  });

  final String wasmUrl;
  final String wasmExecUrl;
  final String? wasmIntegrity;
  final String? wasmExecIntegrity;
}
