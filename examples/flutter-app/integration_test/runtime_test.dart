import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:cel_bridge_flutter_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('validates and evaluates the default rule', (tester) async {
    await tester.pumpWidget(const CelBridgeExampleApp());
    final ready = find.byKey(const ValueKey('runtime-ready'));
    await _waitFor(tester, ready);
    expect(ready, findsOneWidget);
    final evaluate = find.byKey(const ValueKey('evaluate-button'));
    await tester.ensureVisible(evaluate);
    await tester.tap(evaluate);
    final result = find.text('true');
    await _waitFor(tester, result);
    expect(result, findsOneWidget);
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump();
}
