import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cel_bridge_flutter_example/main.dart';

void main() {
  testWidgets('runs the default expression from the workbench', (tester) async {
    await tester.pumpWidget(const CelBridgeExampleApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('runtime-ready')), findsOneWidget);

    final evaluate = find.byKey(const ValueKey('evaluate-button'));
    await tester.ensureVisible(evaluate);
    await tester.tap(evaluate);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
  });
}
