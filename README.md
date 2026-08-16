# cel-bridge

Cross-platform CEL evaluation through one Go `cel-go` runtime. Dart/Flutter and
Rust clients share the same C ABI, Go Wasm backend, and JSON wire protocol;
they do not implement CEL semantics themselves.

The current release is `v0.2.0`. The wire `protocolVersion` remains `1`.

## SDKs

- [Dart / Flutter integration guide](docs/dart.md)
- [Rust integration guide](docs/rust.md)
- [v0.2.0 migration guide](docs/migration-0.2.md)
- [Protocol contract](protocol/README.md)

## Supported platforms

| SDK | Platforms |
| --- | --- |
| Dart / Flutter | Linux x86_64/AArch64, macOS x86_64/arm64, Windows x86_64, Android arm64-v8a/armeabi-v7a/x86_64, iOS device/simulator, Web |
| Rust | Linux x86_64/AArch64, macOS x86_64/arm64, Windows x86_64, Android arm64-v8a/armeabi-v7a/x86_64, iOS device/simulator |

Windows ARM64 and Rust Web/Wasm are not provided in `v0.2.0`. The Rust crate
uses `std`; `no_std` is not supported.

## Dart / Flutter installation

Until pub.dev publication, pin the Git tag and the package subdirectory:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.2.0
      path: sdk/dart
```

Native builds download the matching versioned Release artifact and verify its
SHA-256 manifest. Applications do not need Go in this mode. To build from a
checkout instead, add this to the consuming package:

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: true
```

Minimal usage:

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
```

The full API, typed values, error codes, Web hosting, native source builds, and
iOS fallback are documented in [docs/dart.md](docs/dart.md).

## Rust installation

After crates.io publication:

```toml
[dependencies]
cel-bridge = "0.2.0"
serde_json = "1.0"
```

During the transition, use the Git tag:

```toml
[dependencies]
cel-bridge = { git = "https://github.com/0xfe10/cel-bridge.git", tag = "v0.2.0", package = "cel-bridge" }
```

The default Rust build downloads and verifies a target-specific runtime
artifact. Repository development can use source mode:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo test --manifest-path sdk/rust/Cargo.toml
```

See [docs/rust.md](docs/rust.md) for artifact overrides, Android packaging,
iOS linking, Windows DLL deployment, and error handling.

## Examples

Run the Dart CLI:

```bash
cd examples/dart-cli
dart pub get
dart run
```

Run the Flutter workbench:

```bash
cd examples/flutter-app
flutter pub get
flutter run -d chrome
```

Run the Rust CLI from the checkout:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 \
  cargo run --manifest-path examples/rust-cli/Cargo.toml
```

## Release artifacts

Each release contains versioned Dart and Rust native archives, the Go Wasm
bundle, a restricted runtime source archive, `checksums.txt`, and
`cel-bridge-manifest-v<version>.json`. The manifest v2 entry records
`consumer`, `os`, `architecture`, `linkage`, `sha256`, and `size`.

The Release workflow creates a Draft Release, downloads it again, verifies all
checksums, runs Dart/Rust consumers against the downloaded binaries, and only
then publishes the GitHub Release. pub.dev and crates.io publication remains a
manual approval step.

The historical `v0.1.0` tag and Release are retained unchanged.

## Development checks

```bash
go test ./...
go test -race ./...
(cd sdk/dart && dart pub get && dart analyze && dart test)
(cd tools && dart pub get && dart analyze && dart test)
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo test --manifest-path sdk/rust/Cargo.toml
```

Platform compilation, Flutter checks, browser smoke, artifact manifests, and
Draft Release consumption are defined in
[`check.yml`](.github/workflows/check.yml) and
[`release.yml`](.github/workflows/release.yml).
