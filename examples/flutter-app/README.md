# cel_bridge Flutter workbench

This example is a small developer workbench for the public `cel_bridge` API.
It lets you edit the CEL source, environment, and variables, then run Validate
or Evaluate and inspect runtime information, timing, typed results, and errors.

## Run

```bash
flutter pub get
flutter run -d chrome
```

The example is configured for source builds in the checkout. A normal consumer
can remove that setting and use the version-pinned prebuilt Release artifact.

For self-hosted WebAssembly assets from the repository root:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run sdk/dart/bin/prepare.dart \
  --platform web --output examples/flutter-app/web
cd examples/flutter-app
flutter build web --debug \
  --dart-define=CEL_BRIDGE_WASM_URL=/cel_bridge.wasm \
  --dart-define=CEL_BRIDGE_WASM_EXEC_URL=/wasm_exec.js
```
