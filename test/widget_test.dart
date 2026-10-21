import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_mobile/main.dart';

void main() {
  testWidgets('shows the marketplace sign-in screen', (tester) async {
    await tester.pumpWidget(const MarketplaceApp());
    await tester.pumpAndSettle();

    expect(find.text('NR Online Shopping'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
