# cel-bridge

cel-bridge provides cross-platform CEL evaluation through one Go
[`cel-go`](https://github.com/google/cel-go) runtime. The Dart/Flutter and Rust
SDKs share the same C ABI and JSON protocol; neither SDK reimplements CEL
semantics.

The current source version is `0.5.0`, and the wire `protocolVersion` is `1`.

## At a glance

- one evaluator: Go and `cel-go`;
- compiled Program LRU cache for repeated evaluate calls;
- Dart and Flutter support for desktop, mobile, and Web;
- Rust support for desktop and mobile;
- batch evaluation through `evaluateMany` / `evaluate_many`;
- per-request batch evaluation through `evaluateRequests` / `evaluate_requests`;
- prepared programs, wall-clock deadlines, and runtime profiles;
- fixed, checksummed native artifacts by default;
- optional local source builds for repository and controlled-environment use;
- shared conformance cases across Go, Dart, and Rust.

## Documentation

- [Dart and Flutter integration](docs/dart.md)
- [Rust integration](docs/rust.md)
- [v0.3 artifact migration guide](docs/migration-0.3.md)
- [v0.2.0 migration guide](docs/migration-0.2.md)
- [Protocol contract](protocol/README.md)

## Supported platforms

| SDK | Platforms |
| --- | --- |
| Dart / Flutter | Linux x86_64/AArch64, macOS x86_64/arm64, Windows x86_64, Android arm64-v8a/armeabi-v7a/x86_64, iOS device/simulator, Web |
| Rust | Linux x86_64/AArch64, macOS x86_64/arm64, Windows x86_64, Android arm64-v8a/armeabi-v7a/x86_64, iOS device/simulator |

Windows ARM64 and Rust Web/Wasm are not provided in `v0.5.0`. The Rust crate
uses `std`; `no_std` is not supported.

## Native runtime selection

Both SDKs use the same Go runtime and provide the same two runtime sources, but
their build systems expose the source-build switch differently:

| SDK | Default | Build from source |
| --- | --- | --- |
| Dart / Flutter | Download and verify the matching Release artifact | Set `hooks.user_defines.cel_bridge.build_from_source: true` in the consuming `pubspec.yaml` |
| Rust | Download and verify the matching Release artifact | Set `CEL_BRIDGE_BUILD_FROM_SOURCE=1` for the Cargo command |

The different switches are intentional. Dart build hooks run in a
semi-hermetic environment that strips custom environment variables for
reproducibility and cache correctness. Consequently,
`CEL_BRIDGE_BUILD_FROM_SOURCE` is not visible to the automatic Dart build hook;
the supported Dart configuration is `hooks.user_defines`.

Source mode requires a cel-bridge checkout containing the Go module and
`runtime/` sources, plus Go and the platform C toolchain. Use the default
artifact mode for ordinary third-party builds and published packages.

### Explicit Dart cache preparation

Repository tooling uses the same environment-variable name as Rust when source
compilation is invoked explicitly rather than through the automatic hook:

```bash
cd sdk/dart
dart pub get
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --target linux-x86_64-dynamic
```

This command prepares the package-local native cache. It does not make
`CEL_BRIDGE_BUILD_FROM_SOURCE` an automatic Dart hook setting.

### Important iOS source-build requirement

The iOS runtime is linked as a static XCFramework through CocoaPods. Setting
Dart's `build_from_source: true` only controls the Dart native-asset hook; it
does not build or configure the CocoaPods XCFramework.

For an iOS source or offline build, first build the XCFramework and then expose
its absolute path to Flutter:

```bash
export CEL_BRIDGE_IOS_XCFRAMEWORK_PATH=/absolute/path/to/libcel_bridge.xcframework
flutter build ios --simulator --no-codesign
```

Without `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH`, CocoaPods uses the fixed Release
XCFramework download path. See the [iOS integration notes](docs/dart.md#ios)
for mirror and checksum variables.

## Dart / Flutter

### Installation

Before pub.dev publication, depend on the Git package and pin the release tag:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.4.1
      path: sdk/dart
```

The default build downloads the exact versioned native artifact and verifies
its manifest, size, and SHA-256 checksum. Go is not required.

For source mode from a full repository checkout, configure the consuming
package:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: true
```

### Minimal usage

```dart
import 'package:cel_bridge/cel_bridge.dart';

final runtime = await CelRuntime.initialize();
final result = await runtime.evaluate(
  environment: const {
    'schemaVersion': 1,
    'variables': {'age': {'type': 'int'}},
  },
  source: 'age >= 18',
  variables: {'age': 20},
);

print(result);

final batch = await runtime.evaluateMany(
  environment: const {
    'schemaVersion': 1,
    'variables': {'age': {'type': 'int'}},
  },
  sources: ['age >= 18', 'age >= 21'],
  variables: {'age': 20},
);
```

See [docs/dart.md](docs/dart.md) for typed CEL values, validation, error
handling, Web hosting, artifact mirrors, and platform packaging.

## Rust

### Installation

After crates.io publication:

```toml
[dependencies]
cel-bridge = "0.4.1"
serde_json = "1.0"
```

Before crates.io publication, pin the Git dependency to the release tag:

```toml
[dependencies]
cel-bridge = { git = "https://github.com/0xfe10/cel-bridge.git", tag = "v0.4.1", package = "cel-bridge" }
```

The default Cargo build downloads and verifies the target-specific runtime
artifact. To compile the runtime from a checkout instead:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo build
```

`CEL_BRIDGE_RUNTIME_SOURCE=/absolute/path/to/cel-bridge` can select a separate
runtime checkout. See [docs/rust.md](docs/rust.md) for artifact overrides,
Android packaging, iOS linking, Windows DLL deployment, and error handling.

## Examples

Run the Dart CLI from the repository:

```bash
cd examples/dart-cli
dart pub get
dart run
```

Run the Flutter workbench on Web:

```bash
cd examples/flutter-app
flutter pub get
flutter run -d chrome
```

Run the Rust CLI against a locally compiled runtime:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 \
  cargo run --manifest-path examples/rust-cli/Cargo.toml
```

## Release integrity

Each GitHub Release contains Go-built runtime artifacts selected by platform,
architecture, and linkage, plus the Go Wasm bundle, a restricted runtime source
archive, `checksums.txt`, and `cel-bridge-manifest-v<version>.json`. Dart, Rust,
and other language bindings consume the same compatible runtime artifact.
Manifest entries identify the artifact ID, OS, architecture, linkage, archive
format, libraries, SHA-256 digest, and byte size.

The Release workflow publishes the GitHub Release as soon as artifacts are
built and verified. Dart, Rust, Web, Android, and iOS consumer checks continue
after publication. A failed post-publish check opens an issue and does not
retract the Release. pub.dev and crates.io publication remain manual approval
steps.

The historical `v0.1.0` tag and Release remain unchanged.

## Development

Run the main local checks:

```bash
go test ./...
go test -race ./...
(cd sdk/dart && dart pub get && dart analyze && dart test)
(cd tools && dart pub get && dart analyze && dart test)
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo test --manifest-path sdk/rust/Cargo.toml
```

CI exposes Go, Dart, tools, and Rust as separate checks. Platform jobs compile
and exercise Linux, Windows, Web, Android emulator, and iOS simulator consumers.
The complete definitions are in
[`check.yml`](.github/workflows/check.yml) and
[`release.yml`](.github/workflows/release.yml).
