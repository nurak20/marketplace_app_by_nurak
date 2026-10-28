import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_mobile/core/components/form_dialog.dart';

import 'support/localized_test_app.dart';

void main() {
  testWidgets('releases dialog resources only after the exit transition', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    var released = false;

    await pumpLocalized(
      tester,
      localizedTestApp(
        builder: (context) {
          final localization = EasyLocalization.of(context)!;
          return MaterialApp(
            locale: localization.locale,
            supportedLocales: localization.supportedLocales,
            localizationsDelegates: localization.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showMarketplaceFormDialog<void>(
                    context: context,
                    title: 'Edit',
                    formKey: formKey,
                    content: (_) => TextFormField(controller: controller),
                    onSubmit: (_) async {},
                    onClosed: () {
                      released = true;
                      controller.dispose();
                    },
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(released, isFalse, reason: 'still animating out');
    await tester.pumpAndSettle();

    expect(released, isTrue);
    expect(tester.takeException(), isNull);
  });
}
