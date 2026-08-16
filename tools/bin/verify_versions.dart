import 'dart:io';

import 'package:cel_bridge/src/artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln('usage: dart run bin/verify_versions.dart [--tag <tag>]');
    return;
  }
  try {
    final root = repositoryRoot(args);
    final version = packageVersion(root);
    final packageRoot = Directory('${root.path}/sdk/dart');
    final pubspec = await File(
      '${packageRoot.path}/pubspec.yaml',
    ).readAsString();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null || match.group(1) != version) {
      throw StateError('VERSION and pubspec.yaml version do not match');
    }
    final goRuntimeVersion = _constant(
      File('${root.path}/runtime/celbridge/version.go'),
      RegExp(r'const version = "([^"]+)"'),
      'Go runtime version',
    );
    final dartRuntimeVersion = _constant(
      File('${packageRoot.path}/lib/src/cel_runtime_options.dart'),
      RegExp(r"const packageVersion = '([^']+)';"),
      'Dart runtime version',
    );
    final hookRuntimeVersion = _constant(
      File('${packageRoot.path}/hook/build.dart'),
      RegExp(r"const _runtimeVersion = '([^']+)';"),
      'build hook runtime version',
    );
    if ([
      goRuntimeVersion,
      dartRuntimeVersion,
      hookRuntimeVersion,
    ].any((value) => value != version)) {
      throw StateError('runtime version constants do not match VERSION');
    }
    final dartProtocolVersion = int.parse(
      _constant(
        File('${packageRoot.path}/lib/src/cel_runtime_options.dart'),
        RegExp(r'const wireProtocolVersion = (\d+);'),
        'Dart protocol version',
      ),
    );
    final goProtocolVersion = int.parse(
      _constant(
        File('${root.path}/runtime/internal/protocol/protocol.go'),
        RegExp(r'const Version = (\d+)'),
        'Go protocol version',
      ),
    );
    if (dartProtocolVersion != goProtocolVersion) {
      throw StateError('Go and Dart protocol versions do not match');
    }
    final runtimeOptions = await File(
      '${packageRoot.path}/lib/src/cel_runtime_options.dart',
    ).readAsString();
    if (!runtimeOptions.contains('releases/download/v$version/')) {
      throw StateError('default Web release URL does not match VERSION');
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

String _constant(File file, RegExp pattern, String name) {
  final match = pattern.firstMatch(file.readAsStringSync());
  if (match == null) throw StateError('$name is missing from ${file.path}');
  return match.group(1)!;
}
