import 'cel_issue.dart';

final class CelValidationResult {
  const CelValidationResult({required this.valid, required this.issues});

  factory CelValidationResult.fromJson(Object? json) {
    final value = _object(json, 'validation result');
    final rawIssues = value['issues'];
    if (rawIssues is! List) {
      throw const FormatException('validation result.issues must be a list');
    }
    return CelValidationResult(
      valid: value['valid'] == true,
      issues: [for (final issue in rawIssues) CelIssue.fromJson(issue)],
    );
  }

  final bool valid;
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
