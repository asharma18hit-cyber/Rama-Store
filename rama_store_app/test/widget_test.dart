import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rama_store_app/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders brand title and CTA buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    expect(find.text('RAMA STORE'), findsOneWidget);
    expect(find.text('Enter Store Front'), findsOneWidget);
    expect(find.text('Sign In / Register'), findsOneWidget);
  });
}
