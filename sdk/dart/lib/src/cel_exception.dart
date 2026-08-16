import 'cel_issue.dart';

final class CelBridgeException implements Exception {
  const CelBridgeException({
    required this.code,
    required this.message,
    this.issues = const [],
  });

  factory CelBridgeException.fromJson(Object? json) {
    final value = _object(json, 'bridge error');
    final rawIssues = value['issues'];
    if (rawIssues != null && rawIssues is! List) {
      throw const FormatException('bridge error.issues must be a list');
    }
    return CelBridgeException(
      code: _string(value['code'], 'bridge error.code'),
      message: _string(value['message'], 'bridge error.message'),
      issues: rawIssues is List
          ? [for (final issue in rawIssues) CelIssue.fromJson(issue)]
          : const [],
    );
  }

  final String code;
  final String message;
  final List<CelIssue> issues;

  @override
  String toString() => 'CelBridgeException($code): $message';
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('$name must be an object');
}

String _string(Object? value, String name) {
  if (value is String) {
    return value;
  }
  throw FormatException('$name must be a string');
}
