const packageVersion = '0.3.0';
const wireProtocolVersion = 1;
const _defaultWasmIntegrity =
    'sha256-tj799JDrRN3BxopTeERytIZ2Ynp/GV6eBliGqgnTG6M=';
const _defaultWasmExecIntegrity =
    'sha256-DJSfSZb5qJaY5LXFht4yJJw7abe6rbZNIgBzzASsuhQ=';

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.3.0/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.3.0/wasm_exec.js',
    this.wasmIntegrity = _defaultWasmIntegrity,
    this.wasmExecIntegrity = _defaultWasmExecIntegrity,
  });

  final String wasmUrl;
  final String wasmExecUrl;
  final String? wasmIntegrity;
  final String? wasmExecIntegrity;
}
