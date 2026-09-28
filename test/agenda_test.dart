import 'package:flutter_test/flutter_test.dart';
import 'package:drac_app/services/agenda_service.dart';

void main() {
  test('rejeita datas impossíveis e respeita anos bissextos', () {
    for (final texto in [
      '31/02/2026',
      '29/02/2025',
      '01/13/2026',
      '0/1/2026',
      'abc',
    ]) {
      expect(AgendaService.converterData(texto), isNull);
    }
    expect(AgendaService.converterData('29/02/2024'), DateTime(2024, 2, 29));
  });

  test('período inclui início e fim, mas não aceita data inválida', () {
    final medicamento = {'data_inicio': '25/09/2026', 'data_fim': '26/09/2026'};
    expect(
      AgendaService.valeParaODia(medicamento, DateTime(2026, 9, 24)),
      false,
    );
    expect(
      AgendaService.valeParaODia(medicamento, DateTime(2026, 9, 25, 23)),
      true,
    );
    expect(
      AgendaService.valeParaODia(medicamento, DateTime(2026, 9, 26)),
      true,
    );
    expect(
      AgendaService.valeParaODia(medicamento, DateTime(2026, 9, 27)),
      false,
    );
    expect(
      AgendaService.valeParaODia({'data_fim': '31/02/2026'}, DateTime(2026)),
      false,
    );
  });

  test('status distingue medicamento, data e horário e ignora duplicatas', () {
    final agenda = AgendaSnapshot(
      [
        {'id': 1, 'horario': '09:00', 'ativo': 1},
        {'id': 1, 'horario': '09:00', 'ativo': 1},
        {'id': 1, 'horario': '21:00', 'ativo': 1},
        {'id': 2, 'horario': '09:00', 'ativo': 0},
      ],
      [
        {
          'medicamento_id': 1,
          'data': '26/09/2026',
          'horario': '09:00',
          'administrado': 0,
        },
        {
          'medicamento_id': 1,
          'data': '26/09/2026',
          'horario': '09:00',
          'administrado': 1,
        },
      ],
    );
    final hoje = agenda.dosesDoDia(DateTime(2026, 9, 26));
    expect(hoje.map((r) => r['administrado']), [true, false, false]);
    expect(
      agenda.dosesDoDia(DateTime(2026, 9, 26), apenasAtivos: true).length,
      2,
    );
    expect(
      agenda
          .dosesDoDia(DateTime(2026, 9, 27))
          .every((r) => r['administrado'] == false),
      true,
    );
  });
}
