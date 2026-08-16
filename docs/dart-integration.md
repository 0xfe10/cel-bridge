# cel-bridge Dart / Flutter 集成指南

本文面向需要在 Dart、Flutter、桌面、Android、iOS 或 Web 应用中接入
`cel_bridge` 的开发者。文档以当前 `v0.1.0` API 为准。

`cel_bridge` 将 Go CEL runtime 封装成 Dart API：

- Native 平台通过 C ABI 和动态库运行；
- iOS 通过 Flutter plugin 和静态 XCFramework 运行；
- Web 通过 Go Wasm 运行；
- Dart 代码只处理环境定义、变量、校验结果和类型化的 CEL 值，不需要直接接触 `cel-go` 类型。

## 1. 支持范围

| 平台 | 支持架构 | 运行时资产 | 应用代码是否需要平台分支 |
| --- | --- | --- | --- |
| Linux | x86_64 | `libcel_bridge.so` | 否 |
| Windows | x86_64 | `cel_bridge.dll` | 否 |
| macOS | x86_64、arm64 | `libcel_bridge.dylib` | 否 |
| Android | arm64-v8a、armeabi-v7a、x86_64 | `libcel_bridge.so` | 否 |
| iOS 真机 | arm64 | 静态 `libcel_bridge.a`，由 XCFramework 提供 | 否 |
| iOS Simulator | arm64、x86_64 | 静态 `libcel_bridge.a`，由 XCFramework 提供 | 否 |
| Web | 浏览器 Wasm | `cel_bridge.wasm`、`wasm_exec.js` | 否 |

Linux/Windows ARM64 当前没有 `v0.1.0` Release 资产，接入时会被明确拒绝，
不能用其他架构的动态库替代。

### 版本和工具链

- Dart SDK：`>=3.10.0`；
- Flutter：`>=3.10.0`；
- 使用 Release 资产时，应用不需要安装 Go；
- 选择源码构建时，需要 Go 1.26.x 和对应平台的 C/C++ 工具链；
- Android 源码构建还需要 Android NDK；
- iOS 源码构建需要 Xcode、`xcrun` 和对应 SDK。

## 2. 安装依赖

当前包尚未发布到 pub.dev，接入方应固定 Git tag，而不要依赖未固定的分支：

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.1.0
```

然后在应用目录执行：

```bash
dart pub get
# Flutter 应用使用：
flutter pub get
```

本地开发时可以使用 path dependency：

```yaml
dependencies:
  cel_bridge:
    path: ../cel-bridge
```

推荐始终固定 tag 或 commit。运行时协议版本、Dart 包版本和 Release 资产版本
必须匹配；库在初始化时会主动检查，不匹配会返回 `runtime_mismatch` 或
`protocol_mismatch`。

## 3. 最小 Dart 用法

完整可运行示例见
[`example/dart_cli/bin/main.dart`](../example/dart_cli/bin/main.dart)。下面是最小的
校验和执行流程：

```dart
import 'package:cel_bridge/cel_bridge.dart';

const environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
    'country': {'type': 'string'},
  },
};

Future<void> main() async {
  try {
    final runtime = await CelRuntime.initialize();

    print('runtime: ${runtime.info.runtimeVersion}');
    print('CEL-Go: ${runtime.info.celGoVersion}');

    const source = 'age >= 18 && country == "CN"';
    final validation = await runtime.validate(
      environment: environment,
      source: source,
    );

    if (!validation.valid) {
      for (final issue in validation.issues) {
        print('${issue.code}: ${issue.message} '
            '(${issue.line}:${issue.column})');
      }
      return;
    }

    final result = await runtime.evaluate(
      environment: environment,
      source: source,
      variables: {'age': 20, 'country': 'CN'},
    );

    if (result is CelBoolValue) {
      print('result: ${result.value}');
    }
  } on CelBridgeException catch (error) {
    print('${error.code}: ${error.message}');
  }
}
```

### 初始化规则

`CelRuntime.initialize()` 是异步操作，并且在一个 Dart isolate 内只初始化一次：

```dart
final runtimeFuture = CelRuntime.initialize();
final runtime = await runtimeFuture;
```

建议在应用启动或服务对象中缓存这个 `Future<CelRuntime>`，不要为每次表达式
执行重新初始化。`CelRuntime` 当前没有需要调用的 `dispose()` 方法。

第一次调用传入的 `CelRuntimeOptions` 决定 Web 资产地址；后续调用会复用同一个
初始化结果，不会切换到另一组 URL。初始化失败后，库会清除失败的初始化状态，
后续调用可以重试。

### `validate` 和 `evaluate` 的区别

- `validate` 只编译和类型检查 CEL，不读取变量值；普通语法、未声明变量和类型错误
  会通过 `CelValidationResult.valid == false` 返回；
- `evaluate` 会编译并执行表达式，必须同时提供环境和变量；执行错误会抛出
  `CelBridgeException`；
- 编辑器、表单或规则配置页面应先调用 `validate`，通过后再调用 `evaluate`；
- 服务端已经配置了源码、输入和输出限制，应用应把用户输入限制在业务需要的范围内。

## 4. 环境定义：声明变量类型

`environment` 是变量的类型 schema，不是变量值。`variables` 才是执行时传入的值。

```dart
final environment = CelEnvironment(
  variables: {
    'age': {'type': 'int'},
    'tags': {
      'type': 'list',
      'element': {'type': 'string'},
    },
    'attributes': {
      'type': 'map',
      'key': {'type': 'string'},
      'value': {'type': 'dyn'},
    },
  },
).toJson();

final value = await runtime.evaluate(
  environment: environment,
  source: 'age >= 18 && "premium" in tags',
  variables: {
    'age': 20,
    'tags': ['free', 'premium'],
    'attributes': {'plan': 'pro'},
  },
);
```

也可以直接使用普通的 `Map<String, Object?>`，只要包含：

```json
{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"}
  }
}
```

### 支持的 schema 类型

| `type` | 说明 | 额外字段 |
| --- | --- | --- |
| `null` | CEL null | 无 |
| `bool` | 布尔值 | 无 |
| `int` | 有符号 64 位整数 | 无 |
| `uint` | 无符号 64 位整数 | 无 |
| `double` | 双精度浮点数 | 无 |
| `string` | UTF-8 字符串 | 无 |
| `bytes` | 字节串 | 无 |
| `timestamp` | 时间戳 | 无 |
| `duration` | 时间间隔 | 无 |
| `dyn` | 动态类型 | 无 |
| `list` | 列表 | 必须有 `element` |
| `map` | 映射 | 必须有 `key` 和 `value` |

`map` 的 key 类型当前只支持 `bool`、`int`、`uint` 和 `string`。普通 Dart JSON
map 的 key 必须是字符串；如果需要 CEL 的非字符串 map key，应使用
`CelMapValue`，见下文。

变量名必须是 ASCII 标识符：首字符为字母或 `_`，后续可以包含字母、数字和 `_`。
`if`、`in`、`true`、`false`、`null`、`var` 等 CEL 保留字不能作为变量名。

## 5. Dart 输入值和返回值

### 输入变量

普通 JSON 值可以直接传入：

```dart
final variables = <String, Object?>{
  'enabled': true,
  'name': 'alice',
  'count': 3,
  'ratio': 0.75,
  'tags': ['a', 'b'],
  'attributes': {'region': 'cn'},
  'nothing': null,
};
```

需要精确表达 CEL 类型时使用以下 Dart 类型：

| Dart 类型 | CEL 类型 | 说明 |
| --- | --- | --- |
| `BigInt` | `int` 或 `uint` | 用于避免大整数被 JSON/JavaScript 精度截断 |
| `Uint8List` | `bytes` | 自动进行 Base64 wire 编码 |
| `DateTime` | `timestamp` | 会转换为 UTC |
| `CelDurationValue` | `duration` | 例如 `const CelDurationValue(seconds: 2)` |
| `CelValue` | 对应的明确 CEL 类型 | 用于列表、map、特殊浮点数等场景 |

示例：

```dart
import 'dart:typed_data';

final variables = <String, Object?>{
  'requestId': BigInt.parse('9223372036854775808'),
  'payload': Uint8List.fromList([1, 2, 3]),
  'createdAt': DateTime.now().toUtc(),
  'timeout': const CelDurationValue(seconds: 1, nanoseconds: 500000000),
};
```

`BigInt` 为负数或不超过有符号 64 位上限时按 `int` 编码，更大的非负值按
`uint` 编码。需要明确指定时可以直接使用：

```dart
final variables = <String, Object?>{
  'signed': CelIntValue(BigInt.parse('-7')),
  'unsigned': CelUintValue(BigInt.parse('18446744073709551615')),
};
```

非字符串 CEL map key 使用 `CelMapValue`：

```dart
final variables = <String, Object?>{
  'scores': CelMapValue([
    CelMapEntry(CelIntValue(BigInt.from(1)), const CelStringValue('good')),
    CelMapEntry(CelIntValue(BigInt.from(2)), const CelStringValue('great')),
  ]),
};
```

### 返回值

`evaluate` 返回 `CelValue`，不要把它直接强制转换成 Dart 原始类型；根据具体
子类读取值：

| 类型 | 字段 |
| --- | --- |
| `CelNullValue` | 无 |
| `CelBoolValue` | `bool value` |
| `CelIntValue` | `BigInt value` |
| `CelUintValue` | `BigInt value` |
| `CelDoubleValue` | `double value` |
| `CelStringValue` | `String value` |
| `CelBytesValue` | `Uint8List value` |
| `CelTimestampValue` | UTC `DateTime value` |
| `CelDurationValue` | `int seconds`、`int nanoseconds` |
| `CelListValue` | `List<CelValue> values` |
| `CelMapValue` | `List<CelMapEntry> entries` |

推荐使用 Dart pattern matching 或普通 `is` 判断：

```dart
String display(CelValue value) {
  if (value is CelBoolValue) return value.value.toString();
  if (value is CelIntValue) return value.value.toString();
  if (value is CelUintValue) return value.value.toString();
  if (value is CelStringValue) return value.value;
  return value.toJson().toString();
}
```

`toJson()` 适合日志和调试，不建议把它当作业务层的稳定字符串格式；业务代码
应读取上述类型字段。

## 6. 错误处理和校验结果

所有运行时错误都通过 `CelBridgeException` 抛出：

```dart
try {
  final value = await runtime.evaluate(
    environment: environment,
    source: source,
    variables: variables,
  );
  print(value);
} on CelBridgeException catch (error) {
  switch (error.code) {
    case 'compile_error':
    case 'evaluation_error':
    case 'cost_limit_exceeded':
      // 展示给规则编辑器或业务层。
      print(error.message);
      break;
    default:
      // 记录完整错误并按基础设施错误处理。
      print('${error.code}: ${error.message}');
  }
}
```

应根据 `error.code` 分支，不要根据 `message` 文本匹配。常见顶层错误码：

| 错误码 | 含义 |
| --- | --- |
| `invalid_request` | 请求结构、变量 JSON 或输入值不合法 |
| `invalid_environment` | schema、变量名或类型定义不合法 |
| `source_too_large` | CEL 源码超过 64 KiB |
| `variables_too_large` | 变量 JSON 超过 1 MiB |
| `output_too_large` | 返回值超过 1 MiB |
| `compile_error` | 执行时编译 CEL 失败 |
| `evaluation_error` | CEL 执行返回错误 |
| `cost_limit_exceeded` | 执行成本超过限制 |
| `unsupported_value` | 返回值不能用当前 wire format 表示 |
| `protocol_mismatch` | Dart API 和 runtime 协议版本不一致 |
| `runtime_mismatch` | Dart 包和 native/Wasm runtime 版本不一致 |
| `native_library_load_failed` | 动态库加载或 native 调用失败 |
| `wasm_load_failed` | Wasm 或 `wasm_exec.js` 加载失败 |
| `internal_error` | 未预期的 runtime 错误 |

`CelValidationResult` 的错误不是异常，而是 `issues`：

```dart
final result = await runtime.validate(
  environment: environment,
  source: 'unknownVariable == true',
);

if (!result.valid) {
  for (final issue in result.issues) {
    print('${issue.severity} ${issue.code} '
        'at ${issue.line}:${issue.column}: ${issue.message}');
  }
}
```

常见 issue code 包括 `parse_error`、`undeclared_reference`、`type_error` 和
`compile_error`。环境非法、源码超限等请求级错误仍会抛出
`CelBridgeException`。

### v0.1.0 限制

这些限制由 Go runtime 固定，不是 Dart 侧可配置项：

- 源码和环境 schema 最大 64 KiB；
- 变量输入和返回结果最大 1 MiB；
- schema 类型嵌套最大 16 层；
- 变量值嵌套最大 32 层；
- 单个 list/map 最大 4096 项；
- CEL evaluation cost 上限为 100,000；
- 最多返回 32 个校验 issue。

当前 runtime 不提供自定义函数、proto 类型或 checked-AST artifact；这些能力
会在 `runtime.info.features` 中体现。`v0.1.0` 只有 `costLimit` 为 true。

## 7. Native 资产模式

Dart/Flutter 应用不需要自己调用 `DynamicLibrary.open`、`System.loadLibrary` 或
C ABI。package hook 会在构建阶段准备代码资产，Dart 代码仍然只调用
`CelRuntime`。

### 7.1 使用固定 Release 资产（推荐）

在消费应用的 `pubspec.yaml` 中显式选择 Release 资产：

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: false
```

构建时 hook 会：

1. 根据当前平台和架构选择 target；
2. 下载同版本的 manifest；
3. 从 manifest 找到对应 archive；
4. 校验 archive 大小和 SHA-256；
5. 解压并把 native library 交给 Dart code assets；
6. iOS 由 CocoaPods script phase 准备静态 XCFramework。

这样应用构建机不需要 Go，且不会使用 `latest` 或未固定的 Release URL。

### 7.2 从源码构建

源码构建适合仓库开发、离线调试或需要自己编译 runtime 的场景：

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: true
```

源码构建会在 package checkout 中执行 Go build。Linux、macOS、Windows 需要
对应平台的 C 编译器；Android 需要 NDK；iOS 需要 Xcode SDK。CI 和仓库中的
[`example/dart_cli/pubspec.yaml`](../example/dart_cli/pubspec.yaml) 以及
[`example/flutter_app/pubspec.yaml`](../example/flutter_app/pubspec.yaml) 都使用
这一模式，便于直接从 checkout 验证代码。

如果需要先准备当前主机的 native 缓存，在 `cel-bridge` checkout 根目录执行：

```bash
dart pub get
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --target linux-x86_64
```

可用 target 还包括 `macos-arm64`、`macos-x86_64`、
`windows-x86_64`、`android-arm64-v8a`、`android-armeabi-v7a`、
`android-x86_64`、`ios-arm64` 和两个 iOS simulator target。target 必须和
实际构建平台匹配。

### 7.3 使用本地已编译资产

如果组织内部已有 native library，可以让 hook 从本地目录复制，并继续校验
`.sha256`：

```yaml
hooks:
  user_defines:
    cel_bridge:
      artifact_directory: "file:///absolute/path/to/artifacts/"
```

目录可以直接放库，也可以按 target 分目录：

```text
artifacts/
└── linux-x86_64/
    ├── libcel_bridge.so
    └── libcel_bridge.so.sha256
```

`artifact_directory` 接受带结尾 `/` 的绝对文件目录 URI。它指向的是解压后的
native library，不是 Release archive；缺少 checksum 或 checksum 不匹配会直接
失败。

### 7.4 使用内部 Release 镜像

如果构建环境不能访问 GitHub，可以配置一个 HTTPS 镜像：

```yaml
hooks:
  user_defines:
    cel_bridge:
      build_from_source: false
      release_base_url: "https://artifacts.example.com/cel-bridge/v0.1.0"
```

镜像必须提供当前版本的 manifest 和所有目标 archive，文件名必须保持不变，
例如：

```text
cel-bridge-manifest-v0.1.0.json
cel-bridge-linux-x86_64-v0.1.0.tar.gz
cel-bridge-android-arm64-v8a-v0.1.0.tar.gz
...
```

生产环境要求 HTTPS。`allow_insecure_release_base: true` 只适用于
`http://127.0.0.1` 或 `http://localhost` 的本地测试，不要用于公网或生产镜像。

## 8. Flutter 接入

### 8.1 在 Flutter 应用中调用

Flutter 侧和普通 Dart 侧使用同一套 API，不需要手写 Android JNI、iOS
MethodChannel 或 desktop 动态库加载代码：

```dart
import 'package:flutter/widgets.dart';
import 'package:cel_bridge/cel_bridge.dart';

class RuleScreen extends StatefulWidget {
  const RuleScreen({super.key});

  @override
  State<RuleScreen> createState() => _RuleScreenState();
}

class _RuleScreenState extends State<RuleScreen> {
  late final Future<CelRuntime> _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = CelRuntime.initialize();
  }

  Future<void> checkRule() async {
    final runtime = await _runtime;
    final result = await runtime.evaluate(
      environment: const {
        'schemaVersion': 1,
        'variables': {
          'amount': {'type': 'double'},
        },
      },
      source: 'amount >= 100',
      variables: {'amount': 125.5},
    );

    if (!mounted) return;
    if (result is CelBoolValue) {
      // 更新 UI 或提交业务结果。
      debugPrint('allowed: ${result.value}');
    }
  }
}
```

`CelRuntime.initialize()`、`validate` 和 `evaluate` 都是异步 API。不要在
`build()` 中重复发起初始化或执行；把 runtime future 放在 `initState`、Provider、
Riverpod/Bloc service 或其他生命周期稳定的对象中。

### 8.2 运行仓库中的 Flutter workbench

[`example/flutter_app`](../example/flutter_app) 是一个可直接修改的 workbench，
包含：

- CEL source 编辑；
- environment 和 variables JSON 编辑；
- Validate 和 Evaluate；
- runtime version、protocol version、CEL-Go version 展示；
- 类型化结果、耗时和结构化错误展示；
- Web、desktop、Android、iOS 的构建入口。

运行 Web 版本：

```bash
cd example/flutter_app
flutter pub get
flutter run -d chrome
```

其中的核心调用位于
[`lib/src/workbench_view.dart`](../example/flutter_app/lib/src/workbench_view.dart)。
如果要把 workbench 改造成业务页面，可以优先复用 `_runtime`、`_run`、环境解析
和错误展示的结构。

Flutter widget 单测：

```bash
cd example/flutter_app
flutter test
```

设备集成测试：

```bash
flutter test integration_test/runtime_test.dart
```

集成测试会真正初始化 runtime、执行默认表达式，并确认结果为 `true`。

## 9. 各平台注意事项

### Android

- 不需要手动复制 `libcel_bridge.so` 或调用 `System.loadLibrary`；
- Flutter code assets 会把正确 ABI 的库放入应用；
- 发布 APK/AAB 前至少在目标 ABI 上执行一次 runtime 集成测试；
- 模拟器通常使用 `android-x86_64`，真机常用 `android-arm64-v8a`；
- 如果选择源码构建，确保 NDK 的 clang 可用；否则使用 Release 资产模式。

### iOS

iOS 的 Go runtime 是静态库，当前 Flutter native-assets 输入无法直接声明这个
动态库形态，因此 package 使用 iOS plugin fallback：CocoaPods 在构建前准备
XCFramework，Dart API 不变。

要求和行为：

- iOS deployment target 为 13.0；
- Flutter 构建会自动运行 pod script phase；
- script phase 会从 Release 下载并校验
  `cel-bridge-ios-xcframework-v0.1.0.zip`；
- 运行时不会因为 CEL 调用去下载代码；
- 可以用 `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH` 指向本地 XCFramework；
- 也可以用以下环境变量指定内部镜像：

```bash
export CEL_BRIDGE_IOS_XCFRAMEWORK_URL="https://artifacts.example.com/cel-bridge/v0.1.0/cel-bridge-ios-xcframework-v0.1.0.zip"
export CEL_BRIDGE_IOS_XCFRAMEWORK_CHECKSUM_URL="https://artifacts.example.com/cel-bridge/v0.1.0/checksums.txt"

flutter build ios --simulator --no-codesign
```

如果提供 `CEL_BRIDGE_IOS_XCFRAMEWORK_SHA256`，它会优先于 checksum URL；否则
script 会从 `checksums.txt` 读取对应文件的 SHA-256。

### macOS / Linux / Windows

这些平台使用动态加载的 code asset。正常情况下无需配置额外的 Dart 或 C ABI
代码；如果看到 `native_library_load_failed`，优先检查：

1. 当前架构是否在支持列表中；
2. `dart pub get` 或 `flutter pub get` 是否在正确的应用目录执行；
3. Release manifest 和 archive 是否能从构建机访问；
4. 是否误把其他平台的 `artifact_directory` 指给了当前构建；
5. 源码模式下 Go/C 编译器版本是否正确。

### Web

Web backend 使用 `CelRuntimeOptions` 中的 Wasm URL：

```dart
final runtime = await CelRuntime.initialize(
  options: const CelRuntimeOptions(
    wasmUrl: '/cel_bridge.wasm',
    wasmExecUrl: '/wasm_exec.js',
    wasmIntegrity: null,
    wasmExecIntegrity: null,
  ),
);
```

生产环境更推荐保留 SRI，而不是关闭 integrity：

```dart
final runtime = await CelRuntime.initialize(
  options: const CelRuntimeOptions(
    wasmUrl: 'https://static.example.com/cel_bridge.wasm',
    wasmExecUrl: 'https://static.example.com/wasm_exec.js',
    wasmIntegrity: 'sha256-<wasm-base64-digest>',
    wasmExecIntegrity: 'sha256-<exec-base64-digest>',
  ),
);
```

Wasm 和 `wasm_exec.js` 必须由同一个应用可访问的 HTTPS host 提供，并配置正确
的 CORS header。自托管时，两个文件必须来自同一个 cel-bridge 版本。

如果资产从源码构建，在 cel-bridge checkout 根目录执行：

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 dart run bin/prepare.dart \
  --platform web --output example/flutter_app/web
```

然后在 Flutter Web 构建时指向这些文件：

```bash
cd example/flutter_app
flutter pub get
flutter build web --debug \
  --dart-define=CEL_BRIDGE_WASM_URL=/cel_bridge.wasm \
  --dart-define=CEL_BRIDGE_WASM_EXEC_URL=/wasm_exec.js
```

如果自托管文件使用自定义 SRI，还要同时设置
`CEL_BRIDGE_WASM_INTEGRITY` 和 `CEL_BRIDGE_WASM_EXEC_INTEGRITY`，或在 Dart
代码中传入对应的 `CelRuntimeOptions`。

## 10. 测试建议

接入方至少保留一条包含真实 runtime 的测试，而不只测试 UI：

```dart
test('evaluates the business rule', () async {
  final runtime = await CelRuntime.initialize();
  final value = await runtime.evaluate(
    environment: const {
      'schemaVersion': 1,
      'variables': {
        'age': {'type': 'int'},
      },
    },
    source: 'age >= 18',
    variables: {'age': 20},
  );

  expect((value as CelBoolValue).value, isTrue);
});
```

建议测试层次：

1. schema 和 CEL source 的 `validate` 单测；
2. 关键业务规则的 `evaluate` runtime 测试；
3. Flutter widget test，确认错误和结果能显示；
4. Android/iOS 至少各执行一次真实设备或 simulator/emulator 集成测试；
5. Web 使用实际部署的 Wasm 文件执行一次 smoke test。

仓库本身的验证命令和测试夹具见：

- [`example/flutter_app/test/workbench_test.dart`](../example/flutter_app/test/workbench_test.dart)；
- [`example/flutter_app/integration_test/runtime_test.dart`](../example/flutter_app/integration_test/runtime_test.dart)；
- [`test/native_runtime_test.dart`](../test/native_runtime_test.dart)；
- [`tool/release_consumer`](../tool/release_consumer)。

## 11. 版本升级清单

升级 `cel_bridge` 时不要只改 Dart 依赖版本：

1. 把 Git dependency 的 `ref` 更新到目标 tag；
2. 确认目标 tag 的 Release manifest 存在；
3. 确认应用构建机能下载对应 native archive 或 Wasm 文件；
4. 清理并重新生成应用的 native assets（Flutter 项目可先执行 `flutter clean`）；
5. 检查 `runtime.info.runtimeVersion` 和 `protocolVersion`；
6. 重新执行 native、iOS 和 Web 的最小 runtime 测试。

不要把一个版本的 Dart package、另一个版本的 manifest 和第三个版本的动态库
混用。库在初始化和构建 hook 阶段都会做版本或 checksum 校验，校验失败是预期的
安全行为。

## 12. 相关文件和链接

- [项目 README](../README.md)：安装和架构摘要；
- [Dart CLI example](../example/dart_cli)：最小命令行接入；
- [Flutter workbench](../example/flutter_app)：可运行的跨平台示例；
- [公开 Dart API](../lib/cel_bridge.dart)：所有对外导出的类型；
- [构建 hook](../hook/build.dart)：Release、源码和本地资产选择逻辑；
- [iOS CocoaPods 配置](../ios/cel_bridge.podspec)：XCFramework 下载和校验；
- [v0.1.0 Release](https://github.com/0xfe10/cel-bridge/releases/tag/v0.1.0)：动态库、XCFramework 和 Wasm 资产。
