import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drac_app/screens/configuracoes/despertador_card.dart';
import 'package:drac_app/services/despertador_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DespertadorService.channel, null);
  });
  void mock({bool permitido = true, bool erro = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DespertadorService.channel, (call) async {
          calls.add(call.method);
          if (erro) throw PlatformException(code: 'erro');
          if (call.method == 'status') {
            return {'ativo': false, 'permitido': permitido};
          }
          return null;
        });
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DespertadorCard())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Testar e parar enviam comandos ao Android', (tester) async {
    mock();
    await abrir(tester);
    await tester.tap(find.text('Testar som'));
    await tester.pumpAndSettle();
    expect(calls, contains('testar'));
    await tester.tap(find.text('Parar som'));
    await tester.pumpAndSettle();
    expect(calls, contains('parar'));
  });
  testWidgets('Sem permissão solicita autorização antes de ativar', (
    tester,
  ) async {
    mock(permitido: false);
    await abrir(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(calls, contains('permissoes'));
    expect(calls, isNot(contains('sincronizar')));
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });
  testWidgets('Falha nativa é exibida sem quebrar a tela', (tester) async {
    mock(erro: true);
    await abrir(tester);
    expect(
      find.text('Não foi possível consultar o despertador.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

