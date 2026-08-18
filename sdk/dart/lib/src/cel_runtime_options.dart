const packageVersion = '0.5.0';
const wireProtocolVersion = 1;
const _defaultWasmIntegrity =
    'sha256-NUERWjZ4yxbH9VGPUsj6+qGfnJhxGW1P5PGlvNO/tVI=';
const _defaultWasmExecIntegrity =
    'sha256-DJSfSZb5qJaY5LXFht4yJJw7abe6rbZNIgBzzASsuhQ=';

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.5.0/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.5.0/wasm_exec.js',
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
