import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../cel_exception.dart';
import '../../cel_runtime_options.dart';
import 'go_wasm_interop.dart';

Future<void>? _loaded;
final Map<String, Future<void>> _scripts = {};

Future<void> loadGoWasm(CelRuntimeOptions options) {
  return _loaded ??= _loadGoWasm(options);
}

Future<void> _loadGoWasm(CelRuntimeOptions options) async {
  await _loadScript(options.wasmExecUrl, options.wasmExecIntegrity);
  final go = GoRuntime();
  final response = web.window.fetch(
    options.wasmUrl.toJS,
    _requestInit(options.wasmIntegrity),
  );
  JSAny module;
  try {
    module = await instantiateStreaming(response, go.importObject).toDart;
  } catch (_) {
    final fallbackResponse = await web.window
        .fetch(options.wasmUrl.toJS, _requestInit(options.wasmIntegrity))
        .toDart;
    if (!fallbackResponse.ok) {
      throw StateError(
        'Wasm download failed with HTTP ${fallbackResponse.status}',
      );
    }
    final bytes = await fallbackResponse.arrayBuffer().toDart;
    module = await instantiate(bytes, go.importObject).toDart;
  }
  final instance = (module as WasmInstantiationResult).instance;
  unawaited(go.run(instance).toDart);
  await _waitUntilReady();
}

web.RequestInit _requestInit(String? integrity) =>
    web.RequestInit(integrity: integrity ?? '');

Future<void> _loadScript(String url, String? integrity) {
  if (globalGo?.isA<JSFunction>() ?? false) {
    return Future<void>.value();
  }
  final key = '$url\n$integrity';
  return _scripts[key] ??= _appendScript(url, integrity);
}

Future<void> _appendScript(String url, String? integrity) {
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..crossOrigin = 'anonymous'
    ..src = url;
  if (integrity != null) script.integrity = integrity;
  script.onload = ((JSAny? _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  script.onerror = ((JSAny? _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('failed to load wasm_exec.js from $url'),
      );
    }
  }).toJS;
  final parent = web.document.head ?? web.document.body;
  if (parent == null) {
    completer.completeError(StateError('document has no head or body'));
  } else {
    parent.appendChild(script);
  }
  return completer.future;
}

Future<void> _waitUntilReady() async {
  for (var attempt = 0; attempt < 300; attempt++) {
    final ready = globalCelBridgeReady;
    if (ready?.isA<JSBoolean>() ?? false) {
      if ((ready as JSBoolean).toDart) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw const CelBridgeException(
    code: 'wasm_load_failed',
    message: 'Wasm runtime did not become ready',
  );
}
