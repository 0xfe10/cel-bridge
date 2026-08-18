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
    final rustPackageVersion = _constant(
      File('${root.path}/sdk/rust/Cargo.toml'),
      RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true),
      'Rust package version',
    );
    final rustLockVersion = _constant(
      File('${root.path}/sdk/rust/Cargo.lock'),
      RegExp(
        r'name\s*=\s*"cel-bridge"\s+version\s*=\s*"([^"]+)"',
        multiLine: true,
      ),
      'Rust lockfile version',
    );
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
      rustPackageVersion,
      rustLockVersion,
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
    _requireContains(
      File('${root.path}/README.md'),
      'ref: v$version',
      'README Dart git pin',
    );
    _requireContains(
      File('${root.path}/README.md'),
      'cel-bridge = "$version"',
      'README crates.io pin',
    );
    _requireContains(
      File('${root.path}/README.md'),
      'tag = "v$version"',
      'README git crate pin',
    );
    _requireContains(
      File('${root.path}/sdk/dart/README.md'),
      'ref: v$version',
      'Dart README git pin',
    );
    _requireContains(
      File('${root.path}/docs/dart.md'),
      'ref: v$version',
      'docs/dart.md git pin',
    );
    _requireContains(
      File('${root.path}/docs/rust.md'),
      'cel-bridge = "$version"',
      'docs/rust.md crates.io pin',
    );
    _requireContains(
      File('${root.path}/docs/rust.md'),
      'tag = "v$version"',
      'docs/rust.md git crate pin',
    );
    final dartSdkVersion = File(
      '${root.path}/sdk/dart/VERSION',
    ).readAsStringSync().trim();
    if (dartSdkVersion != version) {
      throw StateError('sdk/dart/VERSION does not match VERSION');
    }
    final toolsVersion = _constant(
      File('${root.path}/tools/pubspec.yaml'),
      RegExp(r'^version:\s*(\S+)', multiLine: true),
      'tools pubspec version',
    );
    if (toolsVersion != version) {
      throw StateError('tools/pubspec.yaml version does not match VERSION');
    }
    final rustExampleVersion = _constant(
      File('${root.path}/examples/rust-cli/Cargo.toml'),
      RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true),
      'Rust example version',
    );
    if (rustExampleVersion != version) {
      throw StateError('examples/rust-cli version does not match VERSION');
    }
    final flutterExample = File(
      '${root.path}/examples/flutter-app/pubspec.yaml',
    ).readAsStringSync();
    if (!RegExp(
      '^version:\\s*${RegExp.escape(version)}(?:\\+\\d+)?\$',
      multiLine: true,
    ).hasMatch(flutterExample)) {
      throw StateError(
        'examples/flutter-app pubspec version does not match VERSION',
      );
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

void _requireContains(File file, String needle, String name) {
  if (!file.readAsStringSync().contains(needle)) {
    throw StateError('$name is missing $needle in ${file.path}');
  }
}
