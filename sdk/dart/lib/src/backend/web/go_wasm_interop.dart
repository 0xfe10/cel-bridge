import 'dart:js_interop';

@JS('Go')
extension type GoRuntime._(JSObject _) implements JSObject {
  external factory GoRuntime();

  external JSObject get importObject;

  external JSPromise<JSAny?> run(JSObject instance);
}

@JS('globalThis')
external JSObject get globalThis;

@JS('globalThis.Go')
external JSAny? get globalGo;

@JS('globalThis.celBridgeReady')
external JSAny? get globalCelBridgeReady;

extension type WasmInstantiationResult._(JSObject _) implements JSObject {
  external JSObject get instance;
}

@JS('WebAssembly.instantiateStreaming')
external JSPromise<JSAny> instantiateStreaming(
  JSPromise<JSAny> response,
  JSObject importObject,
);

@JS('WebAssembly.instantiate')
external JSPromise<JSAny> instantiate(
  JSArrayBuffer bytes,
  JSObject importObject,
);

@JS('celBridgeRuntimeInfo')
external JSString celBridgeRuntimeInfo();

@JS('celBridgeValidate')
external JSString celBridgeValidate(JSString environmentJson, JSString source);

@JS('celBridgeEvaluate')
external JSString celBridgeEvaluate(
  JSString environmentJson,
  JSString source,
  JSString variablesJson,
);

@JS('celBridgeEvaluateMany')
external JSString celBridgeEvaluateMany(
  JSString environmentJson,
  JSString sourcesJson,
  JSString variablesJson,
);

String celBridgeRuntimeInfoJS() => celBridgeRuntimeInfo().toDart;

String celBridgeValidateJS(String environmentJson, String source) {
  return celBridgeValidate(environmentJson.toJS, source.toJS).toDart;
}

String celBridgeEvaluateJS(
  String environmentJson,
  String source,
  String variablesJson,
) {
  return celBridgeEvaluate(
    environmentJson.toJS,
    source.toJS,
    variablesJson.toJS,
  ).toDart;
}

String celBridgeEvaluateManyJS(
  String environmentJson,
  String sourcesJson,
  String variablesJson,
) {
  return celBridgeEvaluateMany(
    environmentJson.toJS,
    sourcesJson.toJS,
    variablesJson.toJS,
  ).toDart;
}
