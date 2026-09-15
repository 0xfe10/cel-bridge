import 'cel_runtime_limits.dart';

const packageVersion = '0.7.3';
const wireProtocolVersion = 1;
const _defaultWasmIntegrity =
    'sha256-Yl73MFSFG520159iJ6LlRNgEsLBNuQkJFlZEyL8waRg=';
const _defaultWasmExecIntegrity =
    'sha256-DJSfSZb5qJaY5LXFht4yJJw7abe6rbZNIgBzzASsuhQ=';

final class CelRuntimeOptions {
  const CelRuntimeOptions({
    this.wasmUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.7.3/cel_bridge.wasm',
    this.wasmExecUrl =
        'https://github.com/0xfe10/cel-bridge/releases/download/v0.7.3/wasm_exec.js',
    this.wasmIntegrity = _defaultWasmIntegrity,
    this.wasmExecIntegrity = _defaultWasmExecIntegrity,
    this.profile,
    this.limits,
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
  final CelRuntimeLimits? limits;
}
