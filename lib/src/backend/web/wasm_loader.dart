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
  await _loadScript(options.wasmExecUrl);
  final go = GoRuntime();
  final response = web.window.fetch(options.wasmUrl.toJS);
  JSAny module;
  try {
    module = await instantiateStreaming(response, go.importObject).toDart;
  } catch (_) {
    final fallbackResponse = await web.window
        .fetch(options.wasmUrl.toJS)
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

Future<void> _loadScript(String url) {
  if (globalGo?.isA<JSFunction>() ?? false) {
    return Future<void>.value();
  }
  return _scripts[url] ??= _appendScript(url);
}

Future<void> _appendScript(String url) {
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()..src = url;
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
