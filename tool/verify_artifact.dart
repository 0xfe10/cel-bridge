import 'dart:convert';
import 'dart:io';

import 'artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: dart run tool/verify_artifact.dart '
      '--manifest <file> [--input <directory>]',
    );
    return;
  }
  try {
    final manifestPath = parseOption(args, 'manifest');
    if (manifestPath == null) throw ArgumentError('--manifest is required');
    final manifestFile = File(manifestPath);
    final value = jsonDecode(await manifestFile.readAsString());
    if (value is! Map) throw StateError('manifest must be a JSON object');
    if (value['manifestVersion'] != 1 ||
        value['protocolVersion'] != protocolVersion) {
      throw StateError('manifest protocol version is unsupported');
    }
    final root = Directory(
      parseOption(args, 'input') ?? manifestFile.parent.path,
    );
    final artifacts = value['artifacts'];
    if (artifacts is! List || artifacts.isEmpty) {
      throw StateError('manifest artifacts must be a non-empty list');
    }
    for (final item in artifacts) {
      if (item is! Map ||
          item['target'] is! String ||
          item['architecture'] is! String ||
          item['file'] is! String ||
          item['sha256'] is! String) {
        throw StateError('manifest contains an invalid artifact entry');
      }
      final name = item['file'] as String;
      if (name.isEmpty ||
          name != File(name).uri.pathSegments.last ||
          !RegExp(r'^cel-bridge-[^/]+-v[^/]+\.(tar\.gz|zip)$').hasMatch(name)) {
        throw StateError('manifest contains an unsafe artifact filename');
      }
      final file = File('${root.path}${Platform.pathSeparator}$name');
      if (!file.existsSync()) throw StateError('missing artifact ${file.path}');
      if (await file.length() != item['size']) {
        throw StateError('artifact size mismatch for ${file.path}');
      }
      if (await sha256File(file) != item['sha256']) {
        throw StateError('artifact SHA-256 mismatch for ${file.path}');
      }
    }
    stdout.writeln('verified ${artifacts.length} artifact(s)');
  } catch (error) {
    stderr.writeln('verify_artifact: $error');
    exitCode = 1;
  }
}
