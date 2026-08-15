import 'dart:io';

import 'artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: dart run tool/build_artifact.dart '
      '--target <target|wasm> [--output <directory>]',
    );
    return;
  }
  try {
    final root = Directory.current;
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
    final build = await buildNativeArtifact(
      root: root,
      target: target,
      output: output,
    );
    stdout.writeln(build.archive!.path);
  } catch (error) {
    stderr.writeln('build_artifact: $error');
    exitCode = 1;
  }
}
