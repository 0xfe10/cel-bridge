const packageVersion = '0.1.0';
const wireProtocolVersion = 1;

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.1.0/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.1.0/wasm_exec.js',
  });

  final String wasmUrl;
  final String wasmExecUrl;
}
