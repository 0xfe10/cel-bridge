# cel-bridge Dart / Flutter Integration Guide

This guide is for developers integrating `cel_bridge` into Dart, Flutter,
desktop, Android, iOS, or Web applications. It targets the current `v0.3.1`
API.

`cel_bridge` wraps the Go CEL runtime in a Dart API:

- Native platforms run through the C ABI and dynamic libraries;
- iOS runs through a Flutter plugin and a static XCFramework;
- Web runs through Go Wasm;
- Dart code only handles environment definitions, variables, validation results,
  and typed CEL values; it never needs to work with `cel-go` types directly.

## 1. Supported platforms

| Platform | Supported architectures | Runtime assets | Platform branches required in app code |
| --- | --- | --- | --- |
| Linux | x86_64 | `libcel_bridge.so` | No |
| Windows | x86_64 | `cel_bridge.dll` | No |
| macOS | x86_64, arm64 | `libcel_bridge.dylib` | No |
| Android | arm64-v8a, armeabi-v7a, x86_64 | `libcel_bridge.so` | No |
| iOS device | arm64 | Static `libcel_bridge.a`, provided by the XCFramework | No |
| iOS Simulator | arm64, x86_64 | Static `libcel_bridge.a`, provided by the XCFramework | No |
| Web | Browser Wasm | `cel_bridge.wasm`, `wasm_exec.js` | No |

Windows ARM64 is not included in `v0.3.1`. Linux AArch64 is supported by the
release artifact and must use the matching `linux-aarch64-dynamic` library.

### Versions and toolchains

- Dart SDK: `>=3.10.0`;
- Flutter: `>=3.10.0`;
- applications do not need Go installed when using Release assets;
- source builds require Go 1.26.x and the platform's C/C++ toolchain;
- Android source builds also require the Android NDK;
- iOS source builds require Xcode, `xcrun`, and the corresponding SDK.

## 2. Install dependencies

The package is not published to pub.dev yet. Consumers should pin a Git tag
instead of depending on an unpinned branch:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.3.1
      path: sdk/dart
```

Run the following in the application directory:

```bash
dart pub get
# For a Flutter application:
flutter pub get
```

For local development, use a path dependency:

```yaml
dependencies:
  cel_bridge:
    path: ../cel-bridge/sdk/dart
```

Always pin a tag or commit. The runtime protocol version, Dart package version,
and Release asset version must match. The library checks this during
initialization and returns `runtime_mismatch` or `protocol_mismatch` when they
do not.

## 3. Minimal Dart usage

A complete runnable example is available in
[`examples/dart-cli/bin/main.dart`](../examples/dart-cli/bin/main.dart). The
following is the smallest validation and evaluation flow:

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
  try {
    final runtime = await CelRuntime.initialize();

    print('runtime: ${runtime.info.runtimeVersion}');
    print('CEL-Go: ${runtime.info.celGoVersion}');

    const source = 'age >= 18 && country == "CN"';
    final validation = await runtime.validate(
      environment: environment,
      source: source,
    );

    if (!validation.valid) {
      for (final issue in validation.issues) {
        print('${issue.code}: ${issue.message} '
            '(${issue.line}:${issue.column})');
      }
      return;
    }

    final result = await runtime.evaluate(
      environment: environment,
      source: source,
      variables: {'age': 20, 'country': 'CN'},
    );

    if (result is CelBoolValue) {
      print('result: ${result.value}');
    }
  } on CelBridgeException catch (error) {
    print('${error.code}: ${error.message}');
  }
}
```

### Initialization rules

`CelRuntime.initialize()` is asynchronous and initializes only once per Dart
isolate:

```dart
final runtimeFuture = CelRuntime.initialize();
final runtime = await runtimeFuture;
```

Cache this `Future<CelRuntime>` during application startup or in a service
object. Do not initialize again for every expression. `CelRuntime` currently
has no `dispose()` method to call.

The `CelRuntimeOptions` passed to the first call determines the Web asset URLs;
later calls reuse the same initialization result and do not switch to another
set of URLs. If initialization fails, the library clears the failed state so
later calls can retry.

### `validate` versus `evaluate`

- `validate` only compiles and type-checks CEL without reading variable values;
  ordinary syntax, undeclared-variable, and type errors are returned through
  `CelValidationResult.valid == false`;
- `evaluate` compiles and executes the expression and requires both the
  environment and variables; execution errors throw `CelBridgeException`;
- editors, forms, and rule-configuration pages should call `validate` before
  calling `evaluate`;
- the runtime already enforces source, input, and output limits, but the
  application should still restrict user input to the required business scope.

## 4. Environment definition: declare variable types

`environment` is the type schema for variables, not their values. `variables`
contains the values passed at evaluation time.

```dart
final environment = CelEnvironment(
  variables: {
    'age': {'type': 'int'},
    'tags': {
      'type': 'list',
      'element': {'type': 'string'},
    },
    'attributes': {
      'type': 'map',
      'key': {'type': 'string'},
      'value': {'type': 'dyn'},
    },
  },
).toJson();

final value = await runtime.evaluate(
  environment: environment,
  source: 'age >= 18 && "premium" in tags',
  variables: {
    'age': 20,
    'tags': ['free', 'premium'],
    'attributes': {'plan': 'pro'},
  },
);
```

You can also use a plain `Map<String, Object?>` as long as it contains:

```json
{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"}
  }
}
```

### Supported schema types

| `type` | Description | Additional fields |
| --- | --- | --- |
| `null` | CEL null | None |
| `bool` | Boolean | None |
| `int` | Signed 64-bit integer | None |
| `uint` | Unsigned 64-bit integer | None |
| `double` | Double-precision floating point | None |
| `string` | UTF-8 string | None |
| `bytes` | Byte string | None |
| `timestamp` | Timestamp | None |
| `duration` | Duration | None |
| `dyn` | Dynamic type | None |
| `list` | List | Requires `element` |
| `map` | Map | Requires `key` and `value` |

Map key types currently support only `bool`, `int`, `uint`, and `string`. A
regular Dart JSON map must use string keys. For a CEL map with non-string keys,
use `CelMapValue` as shown below.

Variable names must be ASCII identifiers: the first character must be a letter
or `_`, followed by letters, digits, or `_`. CEL reserved words such as `if`,
`in`, `true`, `false`, `null`, and `var` cannot be used as variable names.

## 5. Dart input and return values

### Input variables

Ordinary JSON values can be passed directly:

```dart
final variables = <String, Object?>{
  'enabled': true,
  'name': 'alice',
  'count': 3,
  'ratio': 0.75,
  'tags': ['a', 'b'],
  'attributes': {'region': 'cn'},
  'nothing': null,
};
```

Use the following Dart types when the CEL type must be represented precisely:

| Dart type | CEL type | Description |
| --- | --- | --- |
| `BigInt` | `int` or `uint` | Avoids precision loss for large integers in JSON/JavaScript |
| `Uint8List` | `bytes` | Automatically uses Base64 wire encoding |
| `DateTime` | `timestamp` | Converted to UTC |
| `CelDurationValue` | `duration` | For example, `const CelDurationValue(seconds: 2)` |
| `CelValue` | The corresponding explicit CEL type | For lists, maps, special floating-point values, and similar cases |

Example:

```dart
import 'dart:typed_data';

final variables = <String, Object?>{
  'requestId': BigInt.parse('9223372036854775808'),
  'payload': Uint8List.fromList([1, 2, 3]),
  'createdAt': DateTime.now().toUtc(),
  'timeout': const CelDurationValue(seconds: 1, nanoseconds: 500000000),
};
```

Negative `BigInt` values and values within the signed 64-bit range are encoded
as `int`; larger non-negative values are encoded as `uint`. Use the following
types when the encoding must be explicit:

```dart
final variables = <String, Object?>{
  'signed': CelIntValue(BigInt.parse('-7')),
  'unsigned': CelUintValue(BigInt.parse('18446744073709551615')),
};
```

Use `CelMapValue` for non-string CEL map keys:

```dart
final variables = <String, Object?>{
  'scores': CelMapValue([
    CelMapEntry(CelIntValue(BigInt.from(1)), const CelStringValue('good')),
    CelMapEntry(CelIntValue(BigInt.from(2)), const CelStringValue('great')),
  ]),
};
```

### Return values

`evaluate` returns a `CelValue`. Do not cast it directly to a Dart primitive;
read the value from its concrete subclass:

| Type | Fields |
| --- | --- |
| `CelNullValue` | None |
| `CelBoolValue` | `bool value` |
| `CelIntValue` | `BigInt value` |
| `CelUintValue` | `BigInt value` |
| `CelDoubleValue` | `double value` |
| `CelStringValue` | `String value` |
| `CelBytesValue` | `Uint8List value` |
| `CelTimestampValue` | UTC `DateTime value` |
| `CelDurationValue` | `int seconds`, `int nanoseconds` |
| `CelListValue` | `List<CelValue> values` |
| `CelMapValue` | `List<CelMapEntry> entries` |

Prefer Dart pattern matching or ordinary `is` checks:

```dart
String display(CelValue value) {
  if (value is CelBoolValue) return value.value.toString();
  if (value is CelIntValue) return value.value.toString();
  if (value is CelUintValue) return value.value.toString();
  if (value is CelStringValue) return value.value;
  return value.toJson().toString();
}
```

`toJson()` is useful for logging and debugging, but should not be treated as a
stable business-layer string format. Business code should read the typed fields
above.

## 6. Error handling and validation results

All runtime errors are thrown as `CelBridgeException`:

```dart
try {
  final value = await runtime.evaluate(
    environment: environment,
    source: source,
    variables: variables,
  );
  print(value);
} on CelBridgeException catch (error) {
  switch (error.code) {
    case 'compile_error':
    case 'evaluation_error':
    case 'cost_limit_exceeded':
      // Display the error to the rule editor or business layer.
      print(error.message);
      break;
    default:
      // Log the complete error and handle it as an infrastructure failure.
      print('${error.code}: ${error.message}');
  }
}
```

Branch on `error.code`, not on the human-readable `message`. Common top-level
error codes include:

| Error code | Meaning |
| --- | --- |
| `invalid_request` | Request structure, variable JSON, or input value is invalid |
| `invalid_environment` | Environment schema, variable name, or type definition is invalid |
| `source_too_large` | CEL source exceeds 64 KiB |
| `variables_too_large` | Variable JSON exceeds 1 MiB |
| `output_too_large` | Result exceeds 1 MiB |
| `compile_error` | CEL compilation failed during evaluation |
| `evaluation_error` | CEL evaluation returned an error |
| `cost_limit_exceeded` | Evaluation cost exceeded the limit |
| `unsupported_value` | The result cannot be represented by the current wire format |
| `protocol_mismatch` | Dart API and runtime protocol versions do not match |
| `runtime_mismatch` | Dart package and native/Wasm runtime versions do not match |
| `native_library_load_failed` | Native library loading or invocation failed |
| `wasm_load_failed` | Wasm or `wasm_exec.js` could not be loaded |
| `internal_error` | Unexpected runtime error |

`CelValidationResult` reports validation errors in `issues` rather than as
exceptions:

```dart
final result = await runtime.validate(
  environment: environment,
  source: 'unknownVariable == true',
);

if (!result.valid) {
  for (final issue in result.issues) {
    print('${issue.severity} ${issue.code} '
        'at ${issue.line}:${issue.column}: ${issue.message}');
  }
}
```

Common issue codes include `parse_error`, `undeclared_reference`, `type_error`,
and `compile_error`. Request-level errors such as an invalid environment or
oversized source still throw `CelBridgeException`.

### v0.1.0 limits

These limits are fixed by the Go runtime and cannot be configured from Dart:

- source and environment schema: 64 KiB maximum;
- variable input and result: 1 MiB maximum;
- schema type nesting: 16 levels maximum;
- variable value nesting: 32 levels maximum;
- each list/map: 4096 items maximum;
- CEL evaluation cost: 100,000 maximum;
- validation issues: 32 maximum.

The current runtime does not provide custom functions, proto types, or
checked-AST artifacts; these capabilities are exposed through
`runtime.info.features`. In `v0.1.0`, only `costLimit` is true.

## 7. Native asset modes

Dart/Flutter applications do not need to call `DynamicLibrary.open`,
`System.loadLibrary`, or the C ABI themselves. The package hook prepares code
assets during the build, while Dart code continues to call only `CelRuntime`.

### 7.1 Use fixed Release assets (recommended)

Explicitly select Release assets in the consuming application's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: false
```

During the build, the hook will:

1. select the target for the current platform and architecture;
2. download the manifest for the same version;
3. find the corresponding archive in the manifest;
4. verify the archive size and SHA-256 checksum;
5. extract the native library and provide it to Dart code assets;
6. prepare the static XCFramework on iOS through the CocoaPods script phase.

This means application build machines do not need Go and never use `latest` or
an unpinned Release URL.

### 7.2 Build from source

Source builds are useful for repository development, offline debugging, or
cases where the runtime must be compiled locally:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: true
```

Source builds run `go build` in the package checkout. Linux, macOS, and
Windows require the platform C compiler, while Android requires the NDK. The
iOS CocoaPods fallback uses a static XCFramework instead of the dynamic code
asset requested by Flutter; set `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH` to a locally
built XCFramework as described in the iOS section below. CI and the repository's
[`examples/dart-cli/pubspec.yaml`](../examples/dart-cli/pubspec.yaml) and
[`examples/flutter-app/pubspec.yaml`](../examples/flutter-app/pubspec.yaml) both use
this mode so the code can be verified directly from the checkout.

To prepare the native cache for the current host, run this from the
`sdk/dart` package directory:

```bash
cd sdk/dart
dart pub get
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --target linux-x86_64-dynamic
```

Other available targets include `macos-arm64-dynamic`,
`macos-x86_64-dynamic`, `windows-x86_64`, `android-arm64-v8a`,
`android-armeabi-v7a`, `android-x86_64`, `ios-arm64`, and two iOS simulator
targets. The target must match the platform being built.

### 7.3 Use locally compiled assets

If your organization already has a native library, the hook can copy it from a
local directory and continue to verify its `.sha256` checksum:

```yaml
hooks:
  user_defines:
    cel_bridge:
      artifact_directory: "file:///absolute/path/to/artifacts/"
```

The directory can contain the library directly or organize it by target:

```text
artifacts/
└── linux-x86_64-dynamic/
    ├── libcel_bridge.so
    └── libcel_bridge.so.sha256
```

`artifact_directory` accepts an absolute file-directory URI with a trailing `/`.
It points to an extracted native library, not a Release archive. A missing or
mismatched checksum fails the build immediately.

### 7.4 Use an internal Release mirror

If the build environment cannot access GitHub, configure an HTTPS mirror:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: false
      release_base_url: "https://artifacts.example.com/cel-bridge/v0.3.1"
```

The mirror must provide the manifest and every target archive for the current
version, with the original filenames unchanged. For example:

```text
cel-bridge-manifest-v0.3.1.json
cel-bridge-linux-x86_64-dynamic-v0.3.1.tar.gz
cel-bridge-android-arm64-v8a-v0.3.1.tar.gz
...
```

Production environments require HTTPS. `allow_insecure_release_base: true` is
only for local tests using `http://127.0.0.1` or `http://localhost`; do not use
it for public or production mirrors.

## 8. Flutter integration

### 8.1 Call from a Flutter application

Flutter and ordinary Dart use the same API. You do not need to write Android
JNI, iOS MethodChannel, or desktop dynamic-library loading code:

```dart
import 'package:flutter/widgets.dart';
import 'package:cel_bridge/cel_bridge.dart';

class RuleScreen extends StatefulWidget {
  const RuleScreen({super.key});

  @override
  State<RuleScreen> createState() => _RuleScreenState();
}

class _RuleScreenState extends State<RuleScreen> {
  late final Future<CelRuntime> _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = CelRuntime.initialize();
  }

  Future<void> checkRule() async {
    final runtime = await _runtime;
    final result = await runtime.evaluate(
      environment: const {
        'schemaVersion': 1,
        'variables': {
          'amount': {'type': 'double'},
        },
      },
      source: 'amount >= 100',
      variables: {'amount': 125.5},
    );

    if (!mounted) return;
    if (result is CelBoolValue) {
      // Update the UI or submit the business result.
      debugPrint('allowed: ${result.value}');
    }
  }
}
```

`CelRuntime.initialize()`, `validate`, and `evaluate` are all asynchronous
APIs. Do not repeatedly initialize or evaluate from `build()`; keep the runtime
future in `initState`, a Provider, a Riverpod/Bloc service, or another object
with a stable lifecycle.

### 8.2 Run the repository's Flutter workbench

[`examples/flutter-app`](../examples/flutter-app) is a workbench that can be
modified directly. It includes:

- CEL source editing;
- environment and variables JSON editing;
- Validate and Evaluate actions;
- runtime version, protocol version, and CEL-Go version display;
- typed results, timing, and structured error display;
- build entry points for Web, desktop, Android, and iOS.

Run the Web version:

```bash
cd examples/flutter-app
flutter pub get
flutter run -d chrome
```

The core call is in
[`lib/src/workbench_view.dart`](../examples/flutter-app/lib/src/workbench_view.dart).
To turn the workbench into a business page, start by reusing the `_runtime`,
`_run`, environment parsing, and error-display structures.

Flutter widget tests:

```bash
cd examples/flutter-app
flutter test
```

Device integration tests:

```bash
flutter test integration_test/runtime_test.dart
```

The integration test initializes the real runtime, evaluates the default
expression, and verifies that the result is `true`.

## 9. Platform notes

### Android

- Do not copy `libcel_bridge.so` manually or call `System.loadLibrary`;
- Flutter code assets place the library for the correct ABI into the application;
- run at least one runtime integration test on the target ABI before publishing
  an APK/AAB;
- emulators typically use `android-x86_64`, while physical devices commonly use
  `android-arm64-v8a`;
- if you choose a source build, ensure the NDK's clang is available; otherwise
  use Release asset mode.

### iOS

The Go runtime on iOS is a static library. Flutter's current native-assets input
cannot declare this dynamic-library shape directly, so the package uses an iOS
plugin fallback: CocoaPods prepares the XCFramework before the build, while the
Dart API remains unchanged.

Requirements and behavior:

- the iOS deployment target is 13.0;
- `build_from_source: true` alone does not configure CocoaPods; repository or
  offline source verification must also provide a locally built XCFramework via
  `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH`;
- Flutter builds run the pod script phase automatically;
- the script phase downloads and verifies
  `cel-bridge-ios-xcframework-v0.3.1.zip` from the Release;
- runtime CEL calls never download executable code;
- `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH` can point to a local XCFramework;
- the following environment variables can point to an internal mirror:

```bash
export CEL_BRIDGE_IOS_XCFRAMEWORK_URL="https://artifacts.example.com/cel-bridge/v0.3.1/cel-bridge-ios-xcframework-v0.3.1.zip"
export CEL_BRIDGE_IOS_XCFRAMEWORK_CHECKSUM_URL="https://artifacts.example.com/cel-bridge/v0.3.1/checksums.txt"

flutter build ios --simulator --no-codesign
```

If `CEL_BRIDGE_IOS_XCFRAMEWORK_SHA256` is provided, it takes precedence over
the checksum URL. Otherwise, the script reads the file's SHA-256 from
`checksums.txt`.

### macOS / Linux / Windows

These platforms use dynamically loaded code assets. Normally, no additional Dart
or C ABI code is required. If you see `native_library_load_failed`, check the
following first:

1. whether the current architecture is supported;
2. whether `dart pub get` or `flutter pub get` was run in the correct application directory;
3. whether the Release manifest and archive are accessible from the build machine;
4. whether `artifact_directory` accidentally points to another platform's assets;
5. whether the Go/C compiler versions are correct in source-build mode.

### Web

The Web backend uses the Wasm URLs in `CelRuntimeOptions`:

```dart
final runtime = await CelRuntime.initialize(
  options: const CelRuntimeOptions(
    wasmUrl: '/cel_bridge.wasm',
    wasmExecUrl: '/wasm_exec.js',
    wasmIntegrity: null,
    wasmExecIntegrity: null,
  ),
);
```

For production, retaining SRI is recommended instead of disabling integrity:

```dart
final runtime = await CelRuntime.initialize(
  options: const CelRuntimeOptions(
    wasmUrl: 'https://static.example.com/cel_bridge.wasm',
    wasmExecUrl: 'https://static.example.com/wasm_exec.js',
    wasmIntegrity: 'sha256-<wasm-base64-digest>',
    wasmExecIntegrity: 'sha256-<exec-base64-digest>',
  ),
);
```

`wasm_exec.js` and `cel_bridge.wasm` must be served by the same HTTPS host
accessible to the application, with the correct CORS headers. When self-hosting,
both files must come from the same cel-bridge version.

If the assets are built from source, run this from the cel-bridge checkout root:

```bash
cd sdk/dart
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --platform web --output ../../examples/flutter-app/web
```

Then point the Flutter Web build at these files:

```bash
cd ../../examples/flutter-app
flutter pub get
flutter build web --debug \
  --dart-define=CEL_BRIDGE_WASM_URL=/cel_bridge.wasm \
  --dart-define=CEL_BRIDGE_WASM_EXEC_URL=/wasm_exec.js
```

If the self-hosted files use custom SRI values, also set
`CEL_BRIDGE_WASM_INTEGRITY` and `CEL_BRIDGE_WASM_EXEC_INTEGRITY`, or pass the
corresponding `CelRuntimeOptions` from Dart.

## 10. Testing recommendations

Consumers should keep at least one test that uses the real runtime, rather than
testing only the UI:

```dart
test('evaluates the business rule', () async {
  final runtime = await CelRuntime.initialize();
  final value = await runtime.evaluate(
    environment: const {
      'schemaVersion': 1,
      'variables': {
        'age': {'type': 'int'},
      },
    },
    source: 'age >= 18',
    variables: {'age': 20},
  );

  expect((value as CelBoolValue).value, isTrue);
});
```

Recommended test layers:

1. unit tests for `validate` with the schema and CEL source;
2. runtime tests for `evaluate` with critical business rules;
3. Flutter widget tests that verify errors and results are displayed;
4. at least one real-device or simulator/emulator integration test on each of Android and iOS;
5. one Web smoke test using the deployed Wasm files.

For the repository's own verification commands and test fixtures, see:

- [`examples/flutter-app/test/workbench_test.dart`](../examples/flutter-app/test/workbench_test.dart);
- [`examples/flutter-app/integration_test/runtime_test.dart`](../examples/flutter-app/integration_test/runtime_test.dart);
- [`sdk/dart/test/native_runtime_test.dart`](../sdk/dart/test/native_runtime_test.dart);
- [`tools/fixtures/release_consumer`](../tools/fixtures/release_consumer).

## 11. Upgrade checklist

When upgrading `cel_bridge`, do not change only the Dart dependency version:

1. update the Git dependency's `ref` to the target tag;
2. verify that the Release manifest exists for the target tag;
3. verify that the application build machine can download the corresponding native archive or Wasm files;
4. clean and regenerate the application's native assets (a Flutter project can run `flutter clean` first);
5. check `runtime.info.runtimeVersion` and `protocolVersion`;
6. rerun the smallest native, iOS, and Web runtime tests.

Do not mix a Dart package from one version, a manifest from another version, and
a dynamic library from a third version. The library verifies the version or
checksum during initialization and in the build hook; a failed verification is
expected security behavior.

## 12. Related files and links

- [Project README](../README.md): installation and architecture summary;
- [Dart CLI example](../examples/dart-cli): minimal command-line integration;
- [Flutter workbench](../examples/flutter-app): runnable cross-platform example;
- [Public Dart API](../sdk/dart/lib/cel_bridge.dart): all publicly exported types;
- [Build hook](../sdk/dart/hook/build.dart): Release, source, and local-asset selection logic;
- [iOS CocoaPods configuration](../sdk/dart/ios/cel_bridge.podspec): XCFramework download and verification;
- [v0.1.0 Release](https://github.com/0xfe10/cel-bridge/releases/tag/v0.1.0): dynamic libraries, XCFramework, and Wasm assets.
