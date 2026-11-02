import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_ping/app_style.dart';
import 'package:silent_ping/cloud_screen.dart';
import 'package:silent_ping/haptics.dart';

void main() {
  testWidgets(
    'account form scrolls on a small phone with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: silentPingTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          ),
          home: const AccountScreen(),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Sign in'), 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Sign in'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Enter your email and a password of at least 8 characters.'),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Start your circle.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all signals fit large text and send the selected intent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sent = <Signal>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: silentPingTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SignalButtons(onSend: sent.add),
            ),
          ),
        ),
      ),
    );
    for (final signal in Signal.values) {
      await tester.ensureVisible(find.text(signal.label));
      await tester.tap(find.text(signal.label));
    }
    expect(sent, Signal.values);
    expect(tester.takeException(), isNull);
  });

  testWidgets('circle selection remains accessible on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: silentPingTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleTile(
                title: 'Circle ABCD',
                subtitle: 'Connection request / Review',
                onTap: () => selected = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Circle ABCD'));
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup failure offers a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: silentPingTheme(),
        home: LoadingScreen(
          error: 'Connection unavailable',
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
