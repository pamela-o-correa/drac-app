import 'dart:convert';

import '../services/shared_service.dart';
import 'database_helper.dart';

/// SQLite projection: original drac.db remains untouched when joining a group.
class SharedDatabase extends DatabaseHelper {
  SharedDatabase(this.service, String name) : super(databaseName: name);
  final SharedService service;
  @override
  Future<List<Map<String, dynamic>>> buscarMedicamentos() async {
    final version = service.revision;
    return [
      for (final row in await super.buscarMedicamentos())
        {...row, '_shared_version': version},
    ];
  }

  // All writes must go through a validated operation, never the local projection.
  @override
  Future<int> adicionarMedicamento({
    required String nome,
    required String dose,
    String? unidade,
    String? instrucoes,
    String? dataInicio,
    String? dataFim,
    int? cor,
    String? icone,
  }) => throw StateError('Salve medicamento e horários juntos.');
  @override
  Future<int> adicionarHorario({
    required int medicamentoId,
    required String horario,
  }) => throw StateError('Edite o medicamento para alterar seus horários.');
  @override
  Future<int> excluirHorariosDoMedicamento(int medicamentoId) =>
      throw StateError('Edite o medicamento para alterar seus horários.');
  @override
  Future<int> registrarAdministracao({
    required int medicamentoId,
    required String data,
    required String horario,
    required bool administrado,
    String? observacao,
    String? administradoEm,
  }) => throw StateError('Use a confirmação compartilhada de dose.');

  Future<void> prepare() async {
    await (await database).execute(
      'CREATE TABLE IF NOT EXISTS outbox (id TEXT PRIMARY KEY, slot_key TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, status TEXT NOT NULL, response TEXT)',
    );
  }

  Future<void> projectState(Map<String, dynamic> state) async {
    await (await database).transaction((tx) async {
      for (final t in [
        'horarios_medicamentos',
        'medicamentos',
        'tratamentos',
        'drac',
      ]) {
        await tx.delete(t);
      }
      for (final t in [
        'drac',
        'tratamentos',
        'medicamentos',
        'horarios_medicamentos',
      ]) {
        for (final row in state[t] as List) {
          await tx.insert(t, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }

  Future<void> projectSlots(List<Map<String, dynamic>> slots) async {
    await (await database).transaction((tx) async {
      await tx.delete('administracoes');
      for (final row in slots) {
        await tx.insert('administracoes', {
          for (final key in [
            'medicamento_id',
            'data',
            'horario',
            'administrado',
            'administrado_em',
          ])
            key: row[key],
          'observacao': jsonEncode({
            'responsavel': row['actorName'],
            'dose': row['dose'],
            'nome': row['medicationName'],
          }),
        });
      }
    });
  }

  Future<int> save(
    String table,
    int? id,
    Map<String, dynamic> values, {
    int? expected,
    List<String>? times,
  }) async {
    final result = await service.mutate({
      'action': 'save',
      'table': table,
      'id': id,
      'values': values,
      'expected': expected ?? service.revision,
      'times': ?times,
    });
    return (result['id'] as num?)?.toInt() ?? id ?? 0;
  }

  @override
  Future<int> salvarMedicamentoCompleto({
    int? id,
    required Map<String, dynamic> dados,
    required List<String> horarios,
    int? expectedVersion,
  }) => save(
    'medicamentos',
    id,
    dados,
    expected: expectedVersion,
    times: horarios,
  );
  @override
  Future<int> atualizarMedicamento(int id, Map<String, dynamic> dados) =>
      save('medicamentos', id, dados);
  @override
  Future<int> alterarStatusMedicamento(int id, bool ativo) =>
      save('medicamentos', id, {'ativo': ativo ? 1 : 0});
  @override
  Future<int> excluirMedicamento(int id, {int? expectedVersion}) async {
    await service.mutate({
      'action': 'delete',
      'table': 'medicamentos',
      'id': id,
      'expected': expectedVersion ?? service.revision,
    });
    return 1;
  }

  @override
  Future<int> salvarDrac({
    required String nome,
    String? foto,
    double? peso,
    String? nascimento,
    String? observacoes,
  }) => save('drac', null, {
    'nome': nome,
    'foto': foto,
    'peso': peso,
    'nascimento': nascimento,
    'observacoes': observacoes,
  });
  @override
  Future<int> atualizarDrac({
    required int id,
    required String nome,
    String? foto,
    double? peso,
    String? nascimento,
    String? observacoes,
    int? expectedVersion,
  }) => save('drac', id, {
    'nome': nome,
    'foto': foto,
    'peso': peso,
    'nascimento': nascimento,
    'observacoes': observacoes,
  }, expected: expectedVersion);
  @override
  Future<int> adicionarTratamento({
    required String titulo,
    String? veterinario,
    String? dataInicio,
    String? dataFim,
    String? orientacoes,
    String? observacoes,
    bool ativo = true,
  }) => save('tratamentos', null, {
    'titulo': titulo,
    'veterinario': veterinario,
    'data_inicio': dataInicio,
    'data_fim': dataFim,
    'orientacoes': orientacoes,
    'observacoes': observacoes,
    'ativo': ativo ? 1 : 0,
  });
  @override
  Future<int> atualizarTratamento(
    int id,
    Map<String, dynamic> dados, {
    int? expectedVersion,
  }) => save('tratamentos', id, dados, expected: expectedVersion);
  @override
  Future<void> salvarStatusDaDose({
    required int medicamentoId,
    required String data,
    required String horario,
    required bool administrado,
  }) async {
    throw StateError('Use a confirmação de administração compartilhada.');
  }
}
