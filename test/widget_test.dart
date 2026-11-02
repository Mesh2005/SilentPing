import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_ping/main.dart';

void main() {
  testWidgets('contact tap previews locally and long press selects intent', (
    tester,
  ) async {
    final previews = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('silent_ping/haptics'),
      (call) async {
        previews.add(call.arguments as String);
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SilentPingApp());
    expect(find.text('LOCAL DEMO'), findsOneWidget);
    await tester.tap(find.text('Alex'));
    await tester.pump();
    expect(find.text('Thinking of you · local preview'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Sam'));
    await tester.pumpAndSettle();
    expect(find.text('A little signal for Sam'), findsOneWidget);
    await tester.tap(find.text('Arrived safely'));
    await tester.pumpAndSettle();
    expect(find.text('Arrived safely · local preview'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(previews, ['ambient', 'arrival']);
  });
}
