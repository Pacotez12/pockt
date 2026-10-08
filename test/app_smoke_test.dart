import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/app.dart';

void main() {
  testWidgets('PocktApp arranca y muestra el shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PocktApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Pockt');
  });
}
