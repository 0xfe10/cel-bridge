const packageVersion = '0.5.1';
const wireProtocolVersion = 1;
const _defaultWasmIntegrity =
    'sha256-m7oRta6ZTZiIK0knb+IC7TNTKKiSMzij5rU4QEbOpgo=';
const _defaultWasmExecIntegrity =
    'sha256-DJSfSZb5qJaY5LXFht4yJJw7abe6rbZNIgBzzASsuhQ=';

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.5.1/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.5.1/wasm_exec.js',
    this.wasmIntegrity = _defaultWasmIntegrity,
    this.wasmExecIntegrity = _defaultWasmExecIntegrity,
    this.profile,
  });

  final String wasmUrl;
  final String wasmExecUrl;
  final String? wasmIntegrity;
  final String? wasmExecIntegrity;

  /// Runtime profile: `default`, `safe`, or `trusted`.
  ///
  /// When set, initialization replaces the process-wide Go runtime. After
  /// [CelRuntime.dispose], the next [CelRuntime.initialize] recreates it.
  final String? profile;
}
