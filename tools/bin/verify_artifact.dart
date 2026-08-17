import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/src/artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: dart run bin/verify_artifact.dart '
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
    if (value['manifestVersion'] != 3 ||
        value['protocolVersion'] != protocolVersion) {
      throw StateError('manifest protocol version is unsupported');
    }
    final version = value['runtimeVersion'];
    if (version is! String || version.isEmpty) {
      throw StateError('manifest runtimeVersion must be a non-empty string');
    }
    if (value['goVersion'] is! String || value['celGoVersion'] is! String) {
      throw StateError('manifest runtime versions must be strings');
    }
    final root = Directory(
      parseOption(args, 'input') ?? manifestFile.parent.path,
    );
    final artifacts = value['artifacts'];
    if (artifacts is! List || artifacts.isEmpty) {
      throw StateError('manifest artifacts must be a non-empty list');
    }
    final seen = <String>{};
    for (final item in artifacts) {
      if (item is! Map ||
          item['id'] is! String ||
          item['os'] is! String ||
          item['architecture'] is! String ||
          item['linkage'] is! String ||
          item['format'] is! String ||
          item['libraries'] is! List ||
          item['file'] is! String ||
          item['sha256'] is! String ||
          item['size'] is! int) {
        throw StateError('manifest contains an invalid artifact entry');
      }
      final id = item['id'] as String;
      final spec = releaseArtifactSpecs
          .where((candidate) => candidate.id == id)
          .firstOrNull;
      if (spec == null) throw StateError('manifest contains unsupported $id');
      final libraries = item['libraries'] as List;
      if (item['os'] != spec.os ||
          item['architecture'] != spec.architecture ||
          item['linkage'] != spec.linkage ||
          item['format'] != spec.format ||
          libraries.length != spec.libraries.length ||
          !libraries.every((library) => spec.libraries.contains(library))) {
        throw StateError('manifest metadata does not match $id');
      }
      final name = item['file'] as String;
      if (name.isEmpty ||
          name != File(name).uri.pathSegments.last ||
          name != spec.fileName(version)) {
        throw StateError('manifest contains an unsafe artifact filename');
      }
      if (!seen.add(id)) {
        throw StateError('manifest contains duplicate artifact $id');
      }
      final file = File('${root.path}${Platform.pathSeparator}$name');
      if (!file.existsSync()) throw StateError('missing artifact ${file.path}');
      if ((item['size'] as int) < 0 || await file.length() != item['size']) {
        throw StateError('artifact size mismatch for ${file.path}');
      }
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(item['sha256'] as String) ||
          await sha256File(file) != item['sha256']) {
        throw StateError('artifact SHA-256 mismatch for ${file.path}');
      }
    }
    stdout.writeln('verified ${artifacts.length} artifact(s)');
  } catch (error) {
    stderr.writeln('verify_artifact: $error');
    exitCode = 1;
  }
}
