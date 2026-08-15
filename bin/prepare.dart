import 'dart:io';
import 'dart:isolate';

import '../tool/artifact.dart';

Future<void> main(List<String> args) async {
  if (hasOption(args, 'help')) {
    stdout.writeln(
      'usage: CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart '
      '[--platform native|web] [--target <target>] [--output <directory>]',
    );
    return;
  }
  if (!_asBool(Platform.environment['CEL_BRIDGE_BUILD_FROM_SOURCE'])) {
    stderr.writeln('prepare requires CEL_BRIDGE_BUILD_FROM_SOURCE=1');
    exitCode = 64;
    return;
  }
  try {
    final versionUri = await Isolate.resolvePackageUri(
      Uri.parse('package:cel_bridge/VERSION'),
    );
    if (versionUri == null) {
      throw StateError('could not resolve the cel_bridge package root');
    }
    final sourceRoot = Directory.fromUri(versionUri).parent.parent;
    final outputRoot = sourceRoot;
    final platform = parseOption(args, 'platform') ?? 'native';
    if (platform == 'web') {
      final output = Directory(parseOption(args, 'output') ?? 'web/cel_bridge')
        ..createSync(recursive: true);
      final build = await buildWasmArtifact(
        root: sourceRoot,
        output: Directory('.dart_tool/cel_bridge/prepare')
          ..createSync(recursive: true),
        archive: false,
      );
      await build.wasm.copy('${output.path}/cel_bridge.wasm');
      await build.wasmExec.copy('${output.path}/wasm_exec.js');
      stdout.writeln('prepared web assets in ${output.path}');
      return;
    }
    if (platform != 'native') {
      throw ArgumentError('unsupported --platform $platform');
    }
    final targetOption = parseOption(args, 'target');
    final target = targetOption == null
        ? await _hostTarget()
        : ArtifactTarget.parse(targetOption);
    final output = Directory(
      parseOption(args, 'output') ??
          '${outputRoot.path}${Platform.pathSeparator}.dart_tool'
              '${Platform.pathSeparator}cel_bridge'
              '${Platform.pathSeparator}artifacts'
              '${Platform.pathSeparator}${packageVersion(sourceRoot)}',
    )..createSync(recursive: true);
    final build = await buildNativeArtifact(
      root: sourceRoot,
      target: target,
      output: output,
      archive: false,
    );
    stdout.writeln('prepared ${build.rawFile.path}');
  } catch (error) {
    stderr.writeln('prepare: $error');
    exitCode = 1;
  }
}

bool _asBool(String? value) => value == '1' || (value?.toLowerCase() == 'true');

Future<ArtifactTarget> _hostTarget() async {
  final result = await Process.run('go', ['env', 'GOOS', 'GOARCH']);
  if (result.exitCode != 0) throw StateError('could not detect Go host target');
  final lines = result.stdout.toString().trim().split(RegExp(r'\s+'));
  if (lines.length != 2) throw StateError('could not parse Go host target');
  final name = switch ('${lines[0]}-${lines[1]}') {
    'linux-amd64' => 'linux-x86_64',
    'darwin-amd64' => 'macos-x86_64',
    'darwin-arm64' => 'macos-arm64',
    'windows-amd64' => 'windows-x86_64',
    final value => throw StateError('unsupported Go host target $value'),
  };
  return ArtifactTarget.parse(name);
}
