import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cel_bridge/src/artifact.dart' show artifactCacheDirectory;
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

const _runtimeVersion = '0.2.0';
const _protocolVersion = 1;
const _defaultReleaseBase =
    'https://github.com/0xfe10/cel-bridge/releases/download/v$_runtimeVersion';
const _redirectStatusCodes = <int>{
  HttpStatus.movedPermanently,
  HttpStatus.found,
  HttpStatus.seeOther,
  HttpStatus.temporaryRedirect,
  HttpStatus.permanentRedirect,
};

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final target = _target(
      code.targetOS,
      code.targetArchitecture,
      iosSimulator:
          code.targetOS == OS.iOS &&
          code.iOS.targetSdk == IOSSdk.iPhoneSimulator,
      staticLinking:
          code.targetOS == OS.iOS &&
          (code.linkModePreference == LinkModePreference.static ||
              code.linkModePreference == LinkModePreference.preferStatic),
    );
    final sourceBuild = _asBool(input.userDefines['build_from_source']);
    final libraryName = _libraryName(code.targetOS, target.staticLinking);
    final assetPath = input.outputDirectory.resolve(libraryName);
    final sourceRoot = sourceBuild ? _repositoryRoot(input.packageRoot) : null;
    final versionFile = File.fromUri(input.packageRoot.resolve('VERSION'));
    output.dependencies.add(versionFile.uri);

    // Flutter's iOS target currently requests dynamic assets, while Go only
    // supports c-archive for iOS. The iOS plugin links the static XCFramework
    // at app build time, so do not advertise an unusable dynamic asset.
    if (code.targetOS == OS.iOS && !target.staticLinking) return;

    if (sourceBuild) {
      await _buildFromSource(
        input,
        sourceRoot!,
        target,
        assetPath,
        libraryName,
      );
      output.dependencies.addAll([
        sourceRoot.uri.resolve('go.mod'),
        sourceRoot.uri.resolve('go.sum'),
        sourceRoot.uri.resolve('runtime/'),
      ]);
    } else {
      await _downloadArtifact(input, output, target, libraryName, assetPath);
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'cel_bridge',
        file: assetPath,
        linkMode: target.staticLinking
            ? StaticLinking()
            : DynamicLoadingBundled(),
      ),
    );
  });
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

_Target _target(
  OS os,
  Architecture architecture, {
  bool iosSimulator = false,
  required bool staticLinking,
}) {
  if (os == OS.windows && architecture.name == 'arm64') {
    throw UnsupportedError('arm64 Windows artifacts are not included in v0.2');
  }
  final arch = switch (architecture.name) {
    'arm' => 'arm',
    'arm64' => 'arm64',
    'ia32' => '386',
    'riscv64' => 'riscv64',
    'x64' => 'amd64',
    final value => throw UnsupportedError('unsupported architecture $value'),
  };
  final goos = switch (os) {
    OS.android => 'android',
    OS.iOS => 'ios',
    OS.linux => 'linux',
    OS.macOS => 'darwin',
    OS.windows => 'windows',
    final value => throw UnsupportedError(
      'unsupported operating system $value',
    ),
  };
  return _Target(
    os: os,
    goos: goos,
    goarch: arch,
    name: _targetName(os, architecture, iosSimulator: iosSimulator),
    staticLinking: staticLinking,
    iosSimulator: iosSimulator,
  );
}

String _targetName(
  OS os,
  Architecture architecture, {
  bool iosSimulator = false,
}) => switch (os) {
  OS.android => switch (architecture.name) {
    'arm64' => 'android-arm64-v8a',
    'arm' => 'android-armeabi-v7a',
    'x64' => 'android-x86_64',
    final value => '${os.name}-$value',
  },
  OS.iOS =>
    'ios-${architecture.name == 'x64' ? 'x86_64' : architecture.name}'
        '${iosSimulator ? '-simulator' : ''}',
  OS.linux =>
    'linux-${architecture.name == 'x64'
        ? 'x86_64'
        : architecture.name == 'arm64'
        ? 'aarch64'
        : architecture.name}',
  OS.macOS =>
    'macos-${architecture.name == 'x64' ? 'x86_64' : architecture.name}',
  OS.windows =>
    'windows-${architecture.name == 'x64' ? 'x86_64' : architecture.name}',
  final value => '${value.name}-${architecture.name}',
};

String _libraryName(OS os, bool staticLinking) {
  if (staticLinking) return 'libcel_bridge.a';
  return switch (os) {
    OS.windows => 'cel_bridge.dll',
    OS.macOS => 'libcel_bridge.dylib',
    OS.iOS => 'libcel_bridge.dylib',
    _ => 'libcel_bridge.so',
  };
}

Future<void> _downloadArtifact(
  BuildInput input,
  BuildOutputBuilder output,
  _Target target,
  String libraryName,
  Uri assetPath,
) async {
  final releaseBase = _releaseBase(input.userDefines['release_base_url']);
  final hasReleaseOverride =
      input.userDefines['release_base_url'] is String &&
      (input.userDefines['release_base_url'] as String).trim().isNotEmpty;
  final allowInsecure = _asBool(
    input.userDefines['allow_insecure_release_base'],
  );
  final manifestUri = Uri.parse(
    '$releaseBase/cel-bridge-manifest-v$_runtimeVersion.json',
  );
  final localDirectory = input.userDefines.path('artifact_directory');
  if (localDirectory != null) {
    if (await _copyLocalArtifact(
      output,
      localDirectory,
      target,
      libraryName,
      assetPath,
    )) {
      return;
    }
    throw StateError(
      'local artifact directory has no $libraryName for ${target.name}',
    );
  }
  if (!hasReleaseOverride) {
    final cacheDirectory = artifactCacheDirectory(
      input.packageRoot,
      _runtimeVersion,
    ).resolve('${target.name}/');
    if (await _copyLocalArtifact(
      output,
      cacheDirectory,
      target,
      libraryName,
      assetPath,
    )) {
      return;
    }
  }
  final manifest = await _getJson(manifestUri, allowInsecure);
  if (manifest['manifestVersion'] != 2 ||
      manifest['runtimeVersion'] != _runtimeVersion ||
      manifest['protocolVersion'] != _protocolVersion) {
    throw StateError(
      'release manifest does not match cel_bridge $_runtimeVersion',
    );
  }
  final artifacts = manifest['artifacts'];
  if (artifacts is! List) {
    throw StateError('release manifest artifacts is not a list');
  }
  Map<String, Object?>? artifact;
  for (final item in artifacts) {
    if (item is Map &&
        item['target'] == target.name &&
        (item['consumer'] == null || item['consumer'] == 'dart')) {
      artifact = item.map((key, value) => MapEntry(key.toString(), value));
      break;
    }
  }
  if (artifact == null) {
    throw StateError('release has no native artifact for ${target.name}');
  }
  final file = validateReleaseArtifactFile(
    file: _requiredString(artifact['file'], 'artifact.file'),
    target: target.name,
    version: _runtimeVersion,
    goos: target.goos,
  );
  final expectedHash = _requiredString(artifact['sha256'], 'artifact.sha256');
  final expectedSize = artifact['size'];
  if (expectedSize is! int) throw StateError('artifact.size is not an integer');
  final archiveUri = Uri.parse('$releaseBase/$file');
  final archivePath = input.outputDirectory.resolve(file);
  final archiveFile = File.fromUri(archivePath);
  final bytes = await _download(archiveUri, allowInsecure);
  if (bytes.length != expectedSize) {
    throw StateError('artifact size mismatch for $archiveUri');
  }
  if (sha256.convert(bytes).toString() != expectedHash) {
    throw StateError('artifact SHA-256 mismatch for $archiveUri');
  }
  await archiveFile.writeAsBytes(bytes, flush: true);
  final library = _extractLibrary(bytes, file, libraryName);
  await File.fromUri(assetPath).writeAsBytes(library, flush: true);
}

Future<bool> _copyLocalArtifact(
  BuildOutputBuilder output,
  Uri directory,
  _Target target,
  String libraryName,
  Uri assetPath,
) async {
  final candidates = <Uri>[directory, directory.resolve('${target.name}/')];
  for (final candidate in candidates) {
    final file = File.fromUri(candidate.resolve(libraryName));
    if (!file.existsSync()) continue;
    final checksumFile = File.fromUri(candidate.resolve('$libraryName.sha256'));
    if (!checksumFile.existsSync()) {
      throw StateError('local artifact is missing $libraryName.sha256');
    }
    final expected = (await checksumFile.readAsString()).trim();
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (expected != actual) {
      throw StateError('local artifact SHA-256 mismatch for ${file.path}');
    }
    output.dependencies.add(candidate);
    output.dependencies.add(checksumFile.uri);
    await file.copy(assetPath.toFilePath());
    return true;
  }
  return false;
}

Directory _repositoryRoot(Uri packageRoot) {
  final candidate = Directory.fromUri(packageRoot).parent.parent;
  if (!File.fromUri(candidate.uri.resolve('go.mod')).existsSync()) {
    throw StateError(
      'source builds require a cel-bridge repository checkout; '
      'use Release assets for published packages',
    );
  }
  return candidate;
}

Future<void> _buildFromSource(
  BuildInput input,
  Directory sourceRoot,
  _Target target,
  Uri assetPath,
  String libraryName,
) async {
  final go = await Process.run('go', ['version']);
  final version = '${go.stdout}\n${go.stderr}';
  if (!RegExp(r'go1\.26(?:\.|\s)').hasMatch(version)) {
    throw StateError('source build requires Go 1.26; got ${version.trim()}');
  }
  final staticLinking = target.staticLinking;
  final androidCompiler = target.goos == 'android'
      ? _androidCompiler(target.goarch)
      : null;
  final environment = {
    ...Platform.environment,
    'CGO_ENABLED': '1',
    'GOOS': target.goos,
    'GOARCH': target.goarch,
    ...await _compilerEnvironment(target, androidCompiler),
  };
  final result = await Process.run(
    'go',
    [
      'build',
      '-trimpath',
      '-buildmode=${staticLinking ? 'c-archive' : 'c-shared'}',
      '-o',
      assetPath.toFilePath(),
      './runtime/cmd/native',
    ],
    workingDirectory: sourceRoot.path,
    environment: environment,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Go source build failed for ${target.name}: '
      '${result.stdout}\n${result.stderr}',
    );
  }
  if (!File.fromUri(assetPath).existsSync()) {
    throw StateError('Go source build did not produce $libraryName');
  }
}

Future<Map<String, String>> _compilerEnvironment(
  _Target target,
  String? compiler,
) async {
  final values = <String, String>{};
  if (compiler != null) {
    values['CC'] = compiler;
  }
  if (target.os == OS.macOS) {
    final sdkPath = await _xcrun(['--sdk', 'macosx', '--show-sdk-path']);
    values['CC'] = await _xcrun(['--sdk', 'macosx', '--find', 'clang']);
    values['SDKROOT'] = sdkPath;
    values['CGO_CFLAGS_ALLOW'] = r'-isysroot';
    values['CGO_LDFLAGS_ALLOW'] = r'-isysroot';
    final flags = '-isysroot $sdkPath';
    values['CGO_CFLAGS'] = _appendFlags(
      Platform.environment['CGO_CFLAGS'],
      flags,
    );
    values['CGO_LDFLAGS'] = _appendFlags(
      Platform.environment['CGO_LDFLAGS'],
      flags,
    );
    return values;
  }
  if (target.os != OS.iOS) return values;
  final sdk = target.iosSimulator ? 'iphonesimulator' : 'iphoneos';
  final sdkPath = await _xcrun(['--sdk', sdk, '--show-sdk-path']);
  values['CC'] = await _xcrun(['--sdk', sdk, '--find', 'clang']);
  values['SDKROOT'] = sdkPath;
  values['CGO_CFLAGS_ALLOW'] = r'-target|-isysroot';
  values['CGO_LDFLAGS_ALLOW'] = r'-target|-isysroot';
  final architecture = target.goarch == 'amd64' ? 'x86_64' : target.goarch;
  final triple =
      '$architecture-apple-ios${target.iosSimulator ? '-simulator' : ''}';
  final flags = '-isysroot $sdkPath -target $triple';
  values['CGO_CFLAGS'] = _appendFlags(
    Platform.environment['CGO_CFLAGS'],
    flags,
  );
  values['CGO_LDFLAGS'] = _appendFlags(
    Platform.environment['CGO_LDFLAGS'],
    flags,
  );
  return values;
}

Future<String> _xcrun(List<String> args) async {
  final result = await Process.run('xcrun', args);
  if (result.exitCode != 0) {
    throw StateError('xcrun ${args.join(' ')} failed: ${result.stderr}');
  }
  final value = result.stdout.toString().trim();
  if (value.isEmpty) {
    throw StateError('xcrun ${args.join(' ')} returned no value');
  }
  return value;
}

String _appendFlags(String? existing, String flags) => [
  if (existing != null && existing.trim().isNotEmpty) existing.trim(),
  flags,
].join(' ');

String? _androidCompiler(String goarch) {
  final existing = Platform.environment['CC'];
  if (existing != null && existing.isNotEmpty) return existing;
  final ndk =
      Platform.environment['ANDROID_NDK_ROOT'] ??
      Platform.environment['ANDROID_NDK_HOME'];
  if (ndk == null) return null;
  final host = Platform.isWindows
      ? 'windows-x86_64'
      : Platform.isMacOS
      ? 'darwin-x86_64'
      : 'linux-x86_64';
  final compilerName = switch (goarch) {
    'arm64' => 'aarch64-linux-android21-clang',
    'arm' => 'armv7a-linux-androideabi21-clang',
    'amd64' => 'x86_64-linux-android21-clang',
    _ => null,
  };
  if (compilerName == null) return null;
  final compiler = File.fromUri(
    Directory(
      ndk,
    ).uri.resolve('toolchains/llvm/prebuilt/$host/bin/$compilerName'),
  );
  return compiler.existsSync() ? compiler.path : null;
}

String _releaseBase(Object? value) {
  if (value is! String || value.trim().isEmpty) return _defaultReleaseBase;
  return value.trim().replaceFirst(RegExp(r'/+$'), '');
}

Future<Map<String, Object?>> _getJson(Uri uri, bool allowInsecure) async {
  final bytes = await _download(uri, allowInsecure);
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map) {
    throw StateError('JSON manifest at $uri is not an object');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void validateArtifactDownloadUri(
  Uri uri, {
  required bool allowInsecure,
  required bool requireHttps,
}) {
  final localHttp =
      uri.scheme == 'http' &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost');
  if (requireHttps && uri.scheme != 'https') {
    throw StateError('artifact URL redirect must remain HTTPS: $uri');
  }
  if (uri.scheme != 'https' && !(allowInsecure && localHttp)) {
    throw StateError('artifact URL must use HTTPS: $uri');
  }
}

Future<Uint8List> _download(Uri uri, bool allowInsecure) async {
  final client = HttpClient();
  try {
    var current = uri;
    final requireHttps = uri.scheme == 'https';
    for (var redirectCount = 0; ; redirectCount++) {
      validateArtifactDownloadUri(
        current,
        allowInsecure: allowInsecure,
        requireHttps: requireHttps,
      );
      final request = await client.getUrl(current);
      request.followRedirects = false;
      final response = await request.close();
      if (_redirectStatusCodes.contains(response.statusCode)) {
        if (redirectCount >= 5) {
          throw StateError('too many redirects while downloading $uri');
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) {
          throw StateError('redirect has no Location header: $current');
        }
        current = current.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'download failed with HTTP ${response.statusCode}: $current',
        );
      }
      return Uint8List.fromList(
        await response.fold<List<int>>([], (all, chunk) {
          all.addAll(chunk);
          return all;
        }),
      );
    }
  } finally {
    client.close(force: true);
  }
}

Uint8List _extractLibrary(
  List<int> bytes,
  String archiveName,
  String libraryName,
) {
  final archive = archiveName.endsWith('.zip')
      ? ZipDecoder().decodeBytes(bytes)
      : TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  for (final file in archive.files) {
    final normalized = file.name.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (segments.any((segment) => segment == '..') ||
        normalized.startsWith('/')) {
      throw StateError('archive contains an unsafe path: ${file.name}');
    }
    if (!file.isFile || segments.last != libraryName) continue;
    final content = file.readBytes();
    if (content == null) {
      throw StateError('archive entry has no content: ${file.name}');
    }
    return content;
  }
  throw StateError('archive does not contain $libraryName');
}

String _requiredString(Object? value, String name) {
  if (value is String && value.isNotEmpty) return value;
  throw StateError('$name must be a non-empty string');
}

String validateReleaseArtifactFile({
  required String file,
  required String target,
  required String version,
  required String goos,
}) {
  final extension = goos == 'windows' ? 'zip' : 'tar.gz';
  final expected = 'cel-bridge-$target-v$version.$extension';
  if (file != expected) {
    throw StateError('artifact.file must be $expected');
  }
  return file;
}

final class _Target {
  const _Target({
    required this.os,
    required this.goos,
    required this.goarch,
    required this.name,
    required this.staticLinking,
    required this.iosSimulator,
  });

  final OS os;
  final String goos;
  final String goarch;
  final String name;
  final bool staticLinking;
  final bool iosSimulator;
}
