import 'dart:convert';
import 'dart:io';

import 'artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: dart run tool/build_manifest.dart '
      '[--input <directory>] [--output <file>]',
    );
    return;
  }
  try {
    final root = Directory.current;
    final input = Directory(parseOption(args, 'input') ?? 'build/artifacts');
    final output = File(
      parseOption(args, 'output') ??
          '${input.path}${Platform.pathSeparator}${manifestFileName(packageVersion(root))}',
    );
    final archives = input.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.tar.gz') || file.path.endsWith('.zip'),
    );
    final value = await manifest(root: root, archives: archives);
    final entries = value['artifacts'];
    if (entries is! List || entries.isEmpty) {
      throw StateError('no versioned artifacts found in ${input.path}');
    }
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
    final checksums = File(
      '${output.parent.path}${Platform.pathSeparator}checksums.txt',
    );
    await checksums.writeAsString(
      '${entries.map((entry) => '${entry['sha256']}  ${entry['file']}').join('\n')}\n',
      flush: true,
    );
    stdout.writeln(output.path);
  } catch (error) {
    stderr.writeln('build_manifest: $error');
    exitCode = 1;
  }
}
