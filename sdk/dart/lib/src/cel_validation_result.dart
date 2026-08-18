import 'cel_issue.dart';
import 'cel_type.dart';

final class CelValidationResult {
  const CelValidationResult({
    required this.valid,
    required this.issues,
    this.resultType,
  });

  factory CelValidationResult.fromJson(Object? json) {
    final value = _object(json, 'validation result');
    final rawIssues = value['issues'];
    if (rawIssues is! List) {
      throw const FormatException('validation result.issues must be a list');
    }
    return CelValidationResult(
      valid: _bool(value['valid'], 'validation result.valid'),
      resultType: value['resultType'] == null
          ? null
          : CelType.fromJson(value['resultType']),
      issues: [for (final issue in rawIssues) CelIssue.fromJson(issue)],
    );
  }

  final bool valid;
  final CelType? resultType;
  final List<CelIssue> issues;
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

bool _bool(Object? value, String name) {
  if (value is bool) return value;
  throw FormatException('$name must be a boolean');
}
