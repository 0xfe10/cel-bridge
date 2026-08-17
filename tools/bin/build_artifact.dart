import 'dart:io';

import 'package:cel_bridge/src/artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: dart run bin/build_artifact.dart '
      '--target <target|wasm> [--output <directory>] [--no-archive]',
    );
    return;
  }
  try {
    final root = repositoryRoot(args);
    final targetName = parseOption(args, 'target');
    if (targetName == null) throw ArgumentError('--target is required');
    final output = Directory(parseOption(args, 'output') ?? 'build/artifacts')
      ..createSync(recursive: true);
    if (targetName == 'wasm') {
      final build = await buildWasmArtifact(root: root, output: output);
      stdout.writeln(build.archive!.path);
      return;
    }
    final target = ArtifactTarget.parse(targetName);
    final archive = !hasOption(args, 'no-archive');
    final build = await buildNativeArtifact(
      root: root,
      target: target,
      output: output,
      archive: archive,
    );
    stdout.writeln(build.archive?.path ?? build.rawFile.path);
  } catch (error) {
    stderr.writeln('build_artifact: $error');
    exitCode = 1;
  }
}
