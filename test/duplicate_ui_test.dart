import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drac_app/services/dose_confirmation.dart';
import 'package:drac_app/services/shared_service.dart';

void main() {
  final service = SharedService.instance;
  tearDown(() {
    service.slots.clear();
    service.online = false;
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmSharedDose(
                context,
                id: 1,
                date: '27/09/2026',
                time: '08:00',
                name: 'Medicamento de teste',
              ),
              child: const Text('Registrar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dose já marcada exige decisão explícita e identifica responsável',
    (tester) async {
      service.online = true;
      service.slots[SharedService.slotKey(1, '27/09/2026', '08:00')] = {
        'administrado': 1,
        'version': 2,
        'actorName': 'Pamela',
        'administrado_em': '2026-09-27T12:03:00Z',
      };
      await open(tester);
      expect(find.text('ATENÇÃO'), findsOneWidget);
      expect(find.textContaining('Pamela'), findsOneWidget);
      expect(find.text('Registrar outra administração'), findsOneWidget);
      expect(find.text('Corrigir / desmarcar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('ATENÇÃO'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('offline informa incerteza antes de registrar', (tester) async {
    service.online = false;
    await open(tester);
    expect(find.text('Sem confirmação da nuvem'), findsOneWidget);
    expect(find.textContaining('outro cuidador'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
