import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cel_bridge_flutter_example/main.dart';

void main() {
  testWidgets('runs the default expression from the workbench', (tester) async {
    await tester.pumpWidget(const CelBridgeExampleApp());
    await _waitForRuntime(tester);
    expect(find.byKey(const ValueKey('runtime-ready')), findsOneWidget);

    final evaluate = find.byKey(const ValueKey('evaluate-button'));
    await tester.ensureVisible(evaluate);
    await tester.tap(evaluate);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('true'), findsOneWidget);

    final source = find.byKey(const ValueKey('source-field'));
    await tester.ensureVisible(source);
    await tester.enterText(source, 'unknown');
    final validate = find.byKey(const ValueKey('validate-button'));
    await tester.ensureVisible(validate);
    await tester.tap(validate);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.textContaining('1:1'), findsOneWidget);
    expect(find.textContaining('undeclared'), findsOneWidget);

    await tester.enterText(source, 'age >= 18');
    final variables = find.byKey(const ValueKey('variables-field'));
    await tester.ensureVisible(variables);
    await tester.enterText(variables, '{not json');
    await tester.ensureVisible(validate);
    await tester.tap(validate);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(
      find.text('Expression is valid for this environment.'),
      findsOneWidget,
    );
  });
}

Future<void> _waitForRuntime(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    if (find.byKey(const ValueKey('runtime-ready')).evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.pump();
}
