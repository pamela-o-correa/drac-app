import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:drac_app/database/database_helper.dart';
import 'package:drac_app/screens/home/home_screen.dart';
import 'package:drac_app/screens/calendario/calendario_screen.dart';
import 'package:drac_app/screens/historico/historico_screen.dart';
import 'package:drac_app/widgets/dose_card.dart';

class FakeTransaction implements Transaction {
  final String nome;
  FakeTransaction(this.nome);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [
    {'id': 1, 'nome': nome, 'dose': '1', 'horario': '09:00', 'ativo': 1},
  ];
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabase implements Database {
  bool falhar = false;
  int consultas = 0;
  Completer<void>? primeira;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final numero = ++consultas;
    if (falhar) throw StateError('Falha simulada');
    if (numero == 1 && primeira != null) await primeira!.future;
    return action(FakeTransaction('Consulta $numero'));
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFactory implements DatabaseFactory {
  final FakeDatabase db;
  int aberturas = 0;
  FakeFactory(this.db);
  @override
  Future<String> getDatabasesPath() async => 'test';
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    aberturas++;
    return db;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDatabase db;
  late FakeFactory factory;
  setUp(() {
    db = FakeDatabase();
    factory = FakeFactory(db);
    DatabaseHelper.instance = DatabaseHelper(factory: factory);
  });
  // Cada teste usa uma instância isolada; não há conexão nativa para fechar.

  test('aberturas concorrentes compartilham a mesma inicialização', () async {
    await Future.wait(
      List.generate(10, (_) => DatabaseHelper.instance.database),
    );
    expect(factory.aberturas, 1);
  });

  for (final tela in <String, Widget>{
    'início': const HomeScreen(),
    'calendário': const CalendarioScreen(),
    'histórico': const HistoricoScreen(),
  }.entries) {
    testWidgets('${tela.key}: falha permite tentar novamente', (tester) async {
      db.falhar = true;
      await tester.pumpWidget(MaterialApp(home: tela.value));
      await tester.pumpAndSettle();
      final retry = find.text('Não foi possível carregar. Tentar novamente');
      expect(retry, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      db.falhar = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('trocar dia descarta consulta antiga que termina depois', (
    tester,
  ) async {
    db.primeira = Completer<void>();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<DoseCard>(find.byType(DoseCard)).nome, 'Consulta 2');
    db.primeira!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<DoseCard>(find.byType(DoseCard)).nome, 'Consulta 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sair durante consulta não chama setState depois de dispose', (
    tester,
  ) async {
    db.primeira = Completer<void>();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    db.primeira!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
