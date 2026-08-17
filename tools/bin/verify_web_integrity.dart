import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:cel_bridge/src/artifact.dart';

Future<void> main(List<String> args) async {
  try {
    final wasm = _requiredOption(args, 'wasm');
    final wasmExec = _requiredOption(args, 'wasm-exec');
    final root = repositoryRoot(args);
    final source = File(
      '${root.path}/sdk/dart/lib/src/cel_runtime_options.dart',
    ).readAsStringSync();
    await _verify(
      'Wasm',
      File(wasm),
      _constant(source, '_defaultWasmIntegrity'),
    );
    await _verify(
      'wasm_exec.js',
      File(wasmExec),
      _constant(source, '_defaultWasmExecIntegrity'),
    );
  } catch (error) {
    stderr.writeln('verify_web_integrity: $error');
    exitCode = 1;
  }
}

String _requiredOption(List<String> args, String name) {
  final value = parseOption(args, name);
  if (value == null) throw ArgumentError('--$name is required');
  return value;
}

Future<void> _verify(String name, File file, String expected) async {
  final actual =
      'sha256-${base64Encode(sha256.convert(await file.readAsBytes()).bytes)}';
  if (actual != expected) {
    throw StateError(
      '$name integrity mismatch: expected $expected, got $actual',
    );
  }
  stdout.writeln('$name integrity verified');
}

String _constant(String source, String name) {
  final match = RegExp(
    'const ${RegExp.escape(name)}\\s*=\\s*\'([^\']+)\';',
  ).firstMatch(source);
  if (match == null) throw StateError('$name is missing');
  return match.group(1)!;
}
