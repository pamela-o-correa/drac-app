import '../database/database_helper.dart';

/// Regras compartilhadas pela tela inicial, calendário e histórico.
class AgendaService {
  static String formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year.toString().padLeft(4, '0')}';

  static DateTime? converterData(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[2]);
    if (dia == null || mes == null || ano == null || ano < 1 || ano > 9999) {
      return null;
    }
    final data = DateTime(ano, mes, dia);
    return data.day == dia && data.month == mes && data.year == ano
        ? data
        : null;
  }

  static bool valeParaODia(Map<String, dynamic> medicamento, DateTime dia) {
    final data = DateTime(dia.year, dia.month, dia.day);
    for (final campo in ['data_inicio', 'data_fim']) {
      final texto = medicamento[campo]?.toString();
      final limite = converterData(texto);
      // Um período inválido não deve virar silenciosamente uso contínuo.
      if (texto != null && texto.trim().isNotEmpty && limite == null) {
        return false;
      }
      if (limite != null &&
          (campo == 'data_inicio'
              ? data.isBefore(limite)
              : data.isAfter(limite))) {
        return false;
      }
    }
    return true;
  }

  /// Duas consultas por período, sem consultar o banco para cada dose/dia.
  static Future<AgendaSnapshot> carregar(DateTime inicio, DateTime fim) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final horarios = await txn.rawQuery('''
        SELECT m.*, h.horario FROM medicamentos m
        JOIN horarios_medicamentos h ON h.medicamento_id = m.id
        ORDER BY h.horario, m.nome
      ''');
      final registros = await txn.query(
        'administracoes',
        where: "substr(data, 7, 4) || substr(data, 4, 2) || substr(data, 1, 2) BETWEEN ? AND ?",
        whereArgs: [_ordenavel(inicio), _ordenavel(fim)],
      );
      return AgendaSnapshot(horarios, registros);
    });
  }

  static String _ordenavel(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}${data.month.toString().padLeft(2, '0')}${data.day.toString().padLeft(2, '0')}';
}

class AgendaSnapshot {
  final List<Map<String, dynamic>> horarios;
  final Set<String> _administradas;

  AgendaSnapshot(this.horarios, List<Map<String, dynamic>> registros)
    : _administradas = {
        for (final r in registros)
          if (r['administrado'] == 1)
            '${r['medicamento_id']}|${r['data']}|${r['horario']}',
      };

  List<Map<String, dynamic>> dosesDoDia(
    DateTime dia, {
    bool apenasAtivos = false,
  }) {
    final data = AgendaService.formatarData(dia);
    final chaves = <String>{};
    return [
      for (final h in horarios)
        if ((!apenasAtivos || h['ativo'] == 1) &&
            AgendaService.valeParaODia(h, dia) &&
            chaves.add('${h['id']}|${h['horario']}'))
          {
            ...h,
            'administrado': _administradas.contains(
              '${h['id']}|$data|${h['horario']}',
            ),
          },
    ];
  }
}
