import 'dart:convert';
import 'dart:typed_data';

import '../cel_evaluation_request.dart';
import '../cel_runtime_limits.dart';
import '../cel_type.dart';
import '../cel_value.dart';

final _maxCelInt = BigInt.parse('9223372036854775807');
const _taggedValueMarker = r'$cel_bridge';
const _maxValueDepth = 32;

String encodeEnvironment(Map<String, Object?> environment) {
  return jsonEncode(_jsonObject(environment, 'environment'));
}

String encodeVariables(Map<String, Object?> variables) {
  return jsonEncode(_jsonObject(variables, 'variables', valueDepth: 1));
}

String encodeSources(List<String> sources) => jsonEncode(sources);

String encodeRequestOptions({Object? expectedResultType, int? deadlineMs}) {
  if (expectedResultType == null && deadlineMs == null) {
    return '';
  }
  return jsonEncode({
    if (expectedResultType != null)
      'expectedResultType': expectedResultType is CelType
          ? expectedResultType.toExpectedJson()
          : expectedResultType,
    'deadlineMs': ?deadlineMs,
  });
}

String encodeCreateOptions({String? profile, CelRuntimeLimits? limits}) {
  if ((profile == null || profile.isEmpty) && limits == null) {
    return '{}';
  }
  return jsonEncode({
    if (profile != null && profile.isNotEmpty) 'profile': profile,
    if (limits != null) 'limits': limits.toJson(),
  });
}

String encodeEvaluationRequests(List<CelEvaluationRequest> requests) {
  final encoded = [for (final request in requests) _encodedRequest(request)];
  return _encodeEvaluationEnvelope(encoded);
}

final class EncodedEvaluationBatch {
  const EncodedEvaluationBatch({
    required this.payload,
    required this.requestCount,
  });

  final String payload;
  final int requestCount;
}

List<EncodedEvaluationBatch> encodeEvaluationRequestBatches(
  List<CelEvaluationRequest> requests, {
  required int maxRequestCount,
  required int maxRequestBytes,
  required int maxSourceBytes,
}) {
  final encoded = [for (final request in requests) _encodedRequest(request)];
  final batches = <EncodedEvaluationBatch>[];
  var offset = 0;
  while (offset < encoded.length) {
    String? acceptedPayload;
    var acceptedCount = 0;
    var sourceBytes = 0;
    var sourceLimitExceeded = false;
    final maxEnd = (offset + maxRequestCount).clamp(0, encoded.length);
    for (var end = offset; end < maxEnd; end++) {
      sourceBytes += utf8.encode(encoded[end].source ?? '').length;
      if (sourceBytes > maxSourceBytes) {
        sourceLimitExceeded = true;
        break;
      }
      final payload = _encodeEvaluationEnvelope(
        encoded.sublist(offset, end + 1),
      );
      if (utf8.encode(payload).length > maxRequestBytes) break;
      acceptedPayload = payload;
      acceptedCount = end - offset + 1;
    }
    if (acceptedPayload == null) {
      final payload = _encodeEvaluationEnvelope([encoded[offset]]);
      throw CelRequestPayloadTooLarge(
        id: encoded[offset].id,
        actualBytes: sourceLimitExceeded
            ? utf8.encode(encoded[offset].source ?? '').length
            : utf8.encode(payload).length,
        maxBytes: sourceLimitExceeded ? maxSourceBytes : maxRequestBytes,
      );
    }
    batches.add(
      EncodedEvaluationBatch(
        payload: acceptedPayload,
        requestCount: acceptedCount,
      ),
    );
    offset += acceptedCount;
  }
  return batches;
}

final class CelRequestPayloadTooLarge implements Exception {
  const CelRequestPayloadTooLarge({
    required this.id,
    required this.actualBytes,
    required this.maxBytes,
  });

  final String id;
  final int actualBytes;
  final int maxBytes;
}

final class _EncodedRequest {
  const _EncodedRequest({
    required this.id,
    required this.source,
    required this.value,
    required this.variables,
  });

  final String id;
  final String? source;
  final Map<String, Object?> value;
  final Map<String, Object?> variables;
}

_EncodedRequest _encodedRequest(CelEvaluationRequest request) {
  final variables = _jsonObject(request.variables, 'variables', valueDepth: 1);
  return _EncodedRequest(
    id: request.id,
    source: request.source,
    variables: variables,
    value: {
      'id': request.id,
      if (request.source != null) 'source': request.source,
      if (request.programId != null) 'programId': request.programId,
      if (request.expectedResultType != null)
        'expectedResultType': request.expectedResultType is CelType
            ? (request.expectedResultType as CelType).toExpectedJson()
            : request.expectedResultType,
    },
  );
}

String _encodeEvaluationEnvelope(List<_EncodedRequest> requests) {
  final shared = <String, Object?>{};
  if (requests.isNotEmpty) {
    shared.addAll(requests.first.variables);
    shared.removeWhere(
      (key, value) => requests
          .skip(1)
          .any(
            (request) =>
                !request.variables.containsKey(key) ||
                !_jsonEquivalent(request.variables[key], value),
          ),
    );
  }
  return jsonEncode({
    'sharedVariables': shared,
    'requests': [
      for (final request in requests)
        {
          ...request.value,
          'variables': {
            for (final entry in request.variables.entries)
              if (!shared.containsKey(entry.key)) entry.key: entry.value,
          },
        },
    ],
  });
}

bool _jsonEquivalent(Object? left, Object? right) {
  if (left is num || right is num) {
    return left.runtimeType == right.runtimeType && left == right;
  }
  if (identical(left, right) || left == right) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_jsonEquivalent(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_jsonEquivalent(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

Object? _jsonValue(Object? value, [int depth = 0]) {
  if (depth > _maxValueDepth) {
    throw ArgumentError('value nesting exceeds $_maxValueDepth levels');
  }
  if (value is CelValue) return _tagCelValue(value, depth);
  if (value is BigInt) {
    final kind = value.isNegative || value <= _maxCelInt ? 'int' : 'uint';
    return _tag({'kind': kind, 'value': value.toString()});
  }
  if (value is Uint8List) {
    return _tag({'kind': 'bytes', 'value': base64Encode(value)});
  }
  if (value is DateTime) return _tag(CelTimestampValue(value).toJson());
  if (value is CelDurationValue) return _tag(value.toJson());
  if (value is List) {
    return [for (final item in value) _jsonValue(item, depth + 1)];
  }
  if (value is Map) {
    if (value.keys.contains(_taggedValueMarker)) return _tagMap(value, depth);
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('map keys must be strings in JSON variables');
      }
      result[entry.key as String] = _jsonValue(entry.value, depth + 1);
    }
    return result;
  }
  if (value == null || value is bool || value is String) return value;
  if (value is double) {
    return value.isFinite
        ? value
        : _tag({'kind': 'double', 'value': _formatDouble(value)});
  }
  if (value is int) return value;
  throw ArgumentError('unsupported JSON value ${value.runtimeType}');
}

Map<String, Object?> _tag(Map<String, Object?> value) => {
  _taggedValueMarker: true,
  ...value,
};

Map<String, Object?> _tagCelValue(CelValue value, int depth) {
  if (value is CelListValue) {
    return _tag({
      'kind': 'list',
      'items': [for (final item in value.values) _jsonValue(item, depth + 1)],
    });
  }
  if (value is CelMapValue) {
    return _tag({
      'kind': 'map',
      'entries': [
        for (final entry in value.entries)
          {
            'key': _jsonValue(entry.key, depth + 1),
            'value': _jsonValue(entry.value, depth + 1),
          },
      ],
    });
  }
  return _tag(value.toJson());
}

Map<String, Object?> _tagMap(Map value, int depth) {
  final entries = <Map<String, Object?>>[];
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw ArgumentError('map keys must be strings in JSON variables');
    }
    entries.add({
      'key': entry.key as String,
      'value': _jsonValue(entry.value, depth + 1),
    });
  }
  return _tag({'kind': 'map', 'entries': entries});
}

String _formatDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  return value.toString();
}

Map<String, Object?> _jsonObject(
  Map<String, Object?> value,
  String name, {
  int valueDepth = 0,
}) {
  try {
    return {
      for (final entry in value.entries)
        entry.key: _jsonValue(entry.value, valueDepth),
    };
  } on ArgumentError catch (error) {
    throw ArgumentError('$name: $error');
  }
}
