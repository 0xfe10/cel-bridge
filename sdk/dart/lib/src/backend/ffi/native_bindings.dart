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
  symbol: 'cel_bridge_validate_options',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeValidateOptions(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> source,
  Pointer<Utf8> optionsJson,
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

@Native<
  Pointer<Utf8> Function(
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
  )
>(symbol: 'cel_bridge_evaluate_options', assetId: nativeAssetId)
external Pointer<Utf8> celBridgeEvaluateOptions(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> source,
  Pointer<Utf8> variablesJson,
  Pointer<Utf8> optionsJson,
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

@Native<Pointer<Utf8> Function()>(
  symbol: 'cel_bridge_close',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeClose();

@Native<Pointer<Utf8> Function(Pointer<Utf8>)>(
  symbol: 'cel_bridge_create',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeCreate(Pointer<Utf8> optionsJson);

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_evaluate_requests',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeEvaluateRequests(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> requestsJson,
  Pointer<Utf8> optionsJson,
);

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_prepare',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgePrepare(
  Pointer<Utf8> environmentJson,
  Pointer<Utf8> source,
  Pointer<Utf8> optionsJson,
);

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
  symbol: 'cel_bridge_evaluate_program',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeEvaluateProgram(
  Pointer<Utf8> programId,
  Pointer<Utf8> variablesJson,
  Pointer<Utf8> optionsJson,
);

@Native<Pointer<Utf8> Function(Pointer<Utf8>)>(
  symbol: 'cel_bridge_release_program',
  assetId: nativeAssetId,
)
external Pointer<Utf8> celBridgeReleaseProgram(Pointer<Utf8> programId);

@Native<Void Function(Pointer<Utf8>)>(
  symbol: 'cel_bridge_free',
  assetId: nativeAssetId,
)
external void celBridgeFree(Pointer<Utf8> value);
