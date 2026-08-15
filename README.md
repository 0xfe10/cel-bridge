# cel-bridge

Cross-platform CEL evaluation for Dart and Flutter. The Go runtime is exposed
through one JSON wire protocol and is available through native C ABI or Go
Wasm. The Dart API never exposes `cel-go` types.

Version `0.1.0` supports Linux x86_64, Android, macOS, iOS, Windows x86_64,
and Web. Linux and Windows ARM64 release assets are deferred from v1 and are
rejected explicitly until matching artifacts and CI exist. Native consumers use
a version-pinned GitHub Release artifact by default and do not need a Go
toolchain.

## Install

Until the package is published to pub.dev, pin the Git tag in `pubspec.yaml`:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.1.0
```

For local development, use a path dependency instead:

```yaml
dependencies:
  cel_bridge:
    path: ../cel-bridge
```

Run `dart pub get` (or `flutter pub get`) in the consuming package. The build
hook downloads the exact runtime version declared by the package; it never
uses a `latest` URL.

## Dart API

```dart
import 'package:cel_bridge/cel_bridge.dart';

const environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
    'country': {'type': 'string'},
  },
};

Future<void> main() async {
  final runtime = await CelRuntime.initialize();

  final validation = await runtime.validate(
    environment: environment,
    source: 'age >= 18 && country == "CN"',
  );
  if (!validation.valid) {
    for (final issue in validation.issues) {
      print('${issue.code}: ${issue.message} (${issue.line}:${issue.column})');
    }
    return;
  }

  final result = await runtime.evaluate(
    environment: environment,
    source: 'age >= 18 && country == "CN"',
    variables: {'age': 20, 'country': 'CN'},
  );
  if (result is CelBoolValue) print(result.value);
}
```

`runtime.info` exposes `runtimeVersion`, `protocolVersion`, `celGoVersion`,
and feature flags. `validate` returns an invalid result for a bad CEL
expression; it does not throw for ordinary compile issues. Transport,
environment, evaluation, and runtime failures throw `CelBridgeException`.

Evaluation results are typed values such as `CelBoolValue`, `CelIntValue`
(`BigInt`), `CelUintValue`, `CelDoubleValue`, `CelTimestampValue`,
`CelDurationValue`, `CelListValue`, and `CelMapValue`. Integer and binary
values are tagged strings on the wire, so JavaScript and Dart do not lose
precision.

## Environment JSON

The environment is a schema, not the variable values:

```json
{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"},
    "tags": {"type": "list", "element": {"type": "string"}},
    "attributes": {
      "type": "map",
      "key": {"type": "string"},
      "value": {"type": "dyn"}
    }
  }
}
```

Supported v1 types are `null`, `bool`, `int`, `uint`, `double`, `string`,
`bytes`, `timestamp`, `duration`, `dyn`, `list`, and `map`. The runtime checks
schema version, identifiers, nesting, input sizes, evaluation cost, and output
size before crossing the native boundary.

## Errors

Catch `CelBridgeException` and branch on `code`, not on the human-readable
message. `issues` contains source location data when available.

| Code | Meaning |
| --- | --- |
| `invalid_request` | Malformed request or JSON value |
| `invalid_environment` | Unsupported or invalid environment schema |
| `source_too_large` / `variables_too_large` | Input size limit exceeded |
| `output_too_large` | Result exceeded the output limit |
| `compile_error` | CEL source could not be compiled |
| `evaluation_error` | CEL evaluation returned an error |
| `cost_limit_exceeded` | Evaluation cost limit was reached |
| `unsupported_value` | Value cannot be represented by the v1 wire format |
| `protocol_mismatch` / `runtime_mismatch` | SDK and runtime versions disagree |
| `native_library_load_failed` | Native library could not be loaded |
| `wasm_load_failed` | Wasm or `wasm_exec.js` could not be loaded |
| `internal_error` | Unexpected runtime failure |

## Native build modes

The normal consumer path downloads a matching archive from the GitHub Release
and verifies its SHA-256 against the versioned manifest. To build from source,
configure the consuming package explicitly:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: true
```

Source builds require Go 1.26 and the platform C toolchain. The repository's
own examples use this mode. To prepare a local native cache from the checkout:

```bash
dart pub get
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --target linux-x86_64
```

The same command accepts `android-arm64-v8a`, `ios-arm64`, `macos-arm64`, and
`windows-x86_64` on a matching toolchain. A consumer can point
`artifact_directory` at a directory containing a target subdirectory and the
native library; keep the configured directory URI terminated with `/`.

iOS uses a static archive and is linked at application build time. It does not
download executable native code at runtime.

## Web and self-hosted Wasm

The default Web URLs are pinned to the same release version. To self-host the
Wasm files, build them from source and copy both outputs into the app's public
web directory:

```bash
mkdir -p example/flutter_app/web
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --platform web --output example/flutter_app/web

cd example/flutter_app
flutter pub get
flutter build web --debug \
  --dart-define=CEL_BRIDGE_WASM_URL=/cel_bridge.wasm \
  --dart-define=CEL_BRIDGE_WASM_EXEC_URL=/wasm_exec.js \
  --dart-define=CEL_BRIDGE_WASM_INTEGRITY=sha256-<wasm-digest> \
  --dart-define=CEL_BRIDGE_WASM_EXEC_INTEGRITY=sha256-<exec-digest>
```

The integrity values must match the self-hosted files in standard SRI
`sha256-...` form. For a trusted local fixture only, omit these defines to
disable SRI for the custom URLs.

For another host, pass URLs directly:

```dart
final runtime = await CelRuntime.initialize(
  options: const CelRuntimeOptions(
    wasmUrl: 'https://static.example.test/cel_bridge.wasm',
    wasmExecUrl: 'https://static.example.test/wasm_exec.js',
    wasmIntegrity: 'sha256-<wasm-digest>',
    wasmExecIntegrity: 'sha256-<exec-digest>',
  ),
);
```

The host must serve `wasm_exec.js` and `cel_bridge.wasm` over HTTPS with the
appropriate CORS headers. The loader uses streaming instantiation when
available and a verified byte fallback otherwise.

## Examples

```bash
cd example/dart_cli
dart pub get
dart run
```

The Flutter workbench provides editable CEL source, environment and variables,
validation, evaluation, runtime handshake, timing, and structured errors:

```bash
cd example/flutter_app
flutter pub get
flutter run -d chrome
```

See [example/flutter_app/README.md](example/flutter_app/README.md) for
platform-specific build commands.

## Development and verification

```bash
go test ./...
go test -race ./...
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart run tool/verify_versions.dart
```

Artifact commands:

```bash
dart run tool/build_artifact.dart --target linux-x86_64
dart run tool/build_artifact.dart --target wasm
dart run tool/build_manifest.dart
dart run tool/verify_artifact.dart \
  --manifest build/artifacts/cel-bridge-manifest-v0.1.0.json
```

GitHub Actions runs the Go/Dart quality gate, platform builds, browser Wasm
smoke, versioned manifest/checksum generation, Draft Release consumption, and
`dart pub publish --dry-run`.
