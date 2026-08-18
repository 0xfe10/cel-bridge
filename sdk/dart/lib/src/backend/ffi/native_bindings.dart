import 'dart:ffi';

import 'package:ffi/ffi.dart';

const nativeAssetId = 'package:cel_bridge/cel_bridge';

@Native<Pointer<Utf8> Function()>(
  symbol: 'cel_bridge_version',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeVersion();

@Native<Pointer<Utf8> Function()>(
  symbol: 'cel_bridge_runtime_info',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeRuntimeInfo();

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_validate',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeValidate(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> source,
);

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_evaluate',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeEvaluate(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> source,
  Pointer<Utf8> variablesJson,
);

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_evaluate_many',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeEvaluateMany(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> sourcesJson,
  Pointer<Utf8> variablesJson,
);

@Native<Void Function(Pointer<Utf8>)>(
  symbol: 'cel_bridge_free',
  assetId: nativeAssetId,
)
external void celBridgeFree(Pointer<Utf8> value);
