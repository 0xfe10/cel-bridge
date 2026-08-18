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
external JSString celBridgeValidate(
  JSString environmentJson,
  JSString source,
  JSString optionsJson,
);

@JS('celBridgeEvaluate')
external JSString celBridgeEvaluate(
  JSString environmentJson,
  JSString source,
  JSString variablesJson,
  JSString optionsJson,
);

@JS('celBridgeEvaluateMany')
external JSString celBridgeEvaluateMany(
  JSString environmentJson,
  JSString sourcesJson,
  JSString variablesJson,
);

String celBridgeRuntimeInfoJS() => celBridgeRuntimeInfo().toDart;

String celBridgeValidateJS(
  String environmentJson,
  String source, [
  String optionsJson = '',
]) {
  return celBridgeValidate(
    environmentJson.toJS,
    source.toJS,
    optionsJson.toJS,
  ).toDart;
}

String celBridgeEvaluateJS(
  String environmentJson,
  String source,
  String variablesJson, [
  String optionsJson = '',
]) {
  return celBridgeEvaluate(
    environmentJson.toJS,
    source.toJS,
    variablesJson.toJS,
    optionsJson.toJS,
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

@JS('celBridgeEvaluateRequests')
external JSString celBridgeEvaluateRequests(
  JSString environmentJson,
  JSString requestsJson,
  JSString optionsJson,
);

@JS('celBridgePrepare')
external JSString celBridgePrepare(
  JSString environmentJson,
  JSString source,
  JSString optionsJson,
);

@JS('celBridgeEvaluateProgram')
external JSString celBridgeEvaluateProgram(
  JSString programId,
  JSString variablesJson,
  JSString optionsJson,
);

@JS('celBridgeReleaseProgram')
external JSString celBridgeReleaseProgram(JSString programId);

@JS('celBridgeClose')
external JSString celBridgeClose();

@JS('celBridgeCreate')
external JSString celBridgeCreate(JSString optionsJson);

String celBridgeEvaluateRequestsJS(
  String environmentJson,
  String requestsJson, [
  String optionsJson = '',
]) {
  return celBridgeEvaluateRequests(
    environmentJson.toJS,
    requestsJson.toJS,
    optionsJson.toJS,
  ).toDart;
}

String celBridgePrepareJS(
  String environmentJson,
  String source, [
  String optionsJson = '',
]) {
  return celBridgePrepare(
    environmentJson.toJS,
    source.toJS,
    optionsJson.toJS,
  ).toDart;
}

String celBridgeEvaluateProgramJS(
  String programId,
  String variablesJson, [
  String optionsJson = '',
]) {
  return celBridgeEvaluateProgram(
    programId.toJS,
    variablesJson.toJS,
    optionsJson.toJS,
  ).toDart;
}

String celBridgeReleaseProgramJS(String programId) {
  return celBridgeReleaseProgram(programId.toJS).toDart;
}

String celBridgeCloseJS() => celBridgeClose().toDart;

String celBridgeCreateJS([String optionsJson = '']) {
  return celBridgeCreate(optionsJson.toJS).toDart;
}
