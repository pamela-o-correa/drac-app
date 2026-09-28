import 'package:flutter/foundation.dart';

/// Displays actual field changes without exposing the complete state snapshot.
List<String> auditDetails(Map<String, dynamic> event) {
  final before = event['before'], after = event['after'];
  if (after is! Map) return [];
  const labels = {
    'nome': 'Nome',
    'dose': 'Dose',
    'unidade': 'Unidade',
    'instrucoes': 'Observações / instruções',
    'observacoes': 'Observações',
    'data_inicio': 'Início',
    'data_fim': 'Fim',
    'ativo': 'Ativo',
    'titulo': 'Tratamento',
    'orientacoes': 'Orientações',
    'veterinario': 'Veterinário',
    'peso': 'Peso',
    'nascimento': 'Nascimento',
    'administrado': 'Administrado',
  };
  const hidden = {
    'id',
    'version',
    'lastEventId',
    'serverAt',
    'actorUid',
    'actorName',
    'administrado_em',
    'medicamento_id',
  };
  final changes = <String>[];
  void compare(Map old, Map current) {
    for (final key in {...old.keys, ...current.keys}) {
      if (!hidden.contains(key) && old[key] != current[key]) {
        changes.add(
          '${labels[key] ?? key}: ${old[key] ?? '—'} → ${current[key] ?? '—'}',
        );
      }
    }
  }

  if (after['medicamentos'] is List) {
    for (final table in ['drac', 'tratamentos', 'medicamentos']) {
      final oldRows = {
        for (final r in (before?[table] as List? ?? [])) r['id']: r as Map,
      };
      final newRows = {for (final r in after[table] as List) r['id']: r as Map};
      for (final id in {...oldRows.keys, ...newRows.keys}) {
        compare(oldRows[id] ?? {}, newRows[id] ?? {});
      }
    }
    final id = event['targetId'];
    List<String> times(Map? s) => [
      for (final row in (s?['horarios_medicamentos'] as List? ?? []))
        if (row['medicamento_id'] == id) row['horario'] as String,
    ]..sort();
    final oldTimes = times(before as Map?), newTimes = times(after);
    if (!listEquals(oldTimes, newTimes)) {
      changes.add('Horários: ${oldTimes.join(', ')} → ${newTimes.join(', ')}');
    }
  } else if (before is Map) {
    compare(before, after);
  }
  return changes;
}
