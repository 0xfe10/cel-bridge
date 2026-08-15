import 'dart:io';

import 'artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln('usage: dart run tool/verify_versions.dart [--tag <tag>]');
    return;
  }
  try {
    final root = Directory.current;
    final version = packageVersion(root);
    final pubspec = await File('${root.path}/pubspec.yaml').readAsString();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null || match.group(1) != version) {
      throw StateError('VERSION and pubspec.yaml version do not match');
    }
    final tag = parseOption(args, 'tag');
    if (tag != null && tag != 'v$version') {
      throw StateError('tag $tag does not match v$version');
    }
    stdout.writeln('version $version is consistent');
  } catch (error) {
    stderr.writeln('verify_versions: $error');
    exitCode = 1;
  }
}
