import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drac_app/main.dart' as app;
import 'package:drac_app/database/database_helper.dart';
import 'package:drac_app/database/shared_database.dart';
import 'package:drac_app/services/shared_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: telas existentes e cache compartilhado sem alterar dados reais',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Drác ♡'), findsOneWidget);
      expect(
        find.text('Não foi possível carregar. Tentar novamente'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Calendário', 'Histórico', 'Config.']) {
        await tester.tap(find.widgetWithText(NavigationDestination, label));
        await tester.pumpAndSettle();
        expect(
          find.text('Não foi possível carregar. Tentar novamente'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Conta e cuidado compartilhado'));
      await tester.pumpAndSettle();
      expect(find.text('Cuidado compartilhado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final original = await DatabaseHelper.instance.buscarMedicamentos();
      final cache = SharedDatabase(
        SharedService.instance,
        'drac_integration_only.db',
      );
      await cache.prepare();
      await cache.projectState({
        'drac': <Map<String, dynamic>>[],
        'tratamentos': <Map<String, dynamic>>[],
        'medicamentos': [
          {'id': 1, 'nome': 'Teste isolado', 'dose': '1', 'ativo': 1},
        ],
        'horarios_medicamentos': [
          {'id': 1, 'medicamento_id': 1, 'horario': '08:00'},
        ],
      });
      await cache.projectSlots([
        {
          'medicamento_id': 1,
          'data': '27/09/2026',
          'horario': '08:00',
          'administrado': 1,
          'administrado_em': '2026-09-27T12:00:00Z',
          'actorName': 'Teste',
          'dose': '1',
          'medicationName': 'Teste isolado',
        },
      ]);
      expect(
        (await cache.buscarAdministracoesPorData('27/09/2026'))
            .single['administrado'],
        1,
      );
      final db = await cache.database;
      await db.delete('outbox');
      await db.insert('outbox', {
        'id': 'isolated-operation',
        'slot_key': 'slot',
        'payload': '{}',
        'status': 'pending',
      });
      await cache.fecharBanco();
      final reopened = SharedDatabase(
        SharedService.instance,
        'drac_integration_only.db',
      );
      await reopened.prepare();
      expect(
        (await (await reopened.database).query('outbox')).single['id'],
        'isolated-operation',
      );
      expect(await DatabaseHelper.instance.buscarMedicamentos(), original);
      await (await reopened.database).delete('outbox');
      await reopened.fecharBanco();
    },
  );
}
