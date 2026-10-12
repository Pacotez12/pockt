import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/design/motion.dart';

void main() {
  testWidgets('Pressable se anuncia como botón con su etiqueta', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: Pressable(
          semanticLabel: 'Volver',
          onTap: () {},
          child: const Icon(Icons.arrow_back),
        ),
      ),
    ));

    expect(
      tester.getSemantics(find.byType(Pressable)),
      matchesSemantics(label: 'Volver', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
