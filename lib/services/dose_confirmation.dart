import 'package:flutter/material.dart';

import 'shared_service.dart';

String doseMoment(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'horário não informado';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<void> confirmSharedDose(
  BuildContext context, {
  required int id,
  required String date,
  required String time,
  required String name,
}) async {
  final s = SharedService.instance;
  final slot = s.slot(id, date, time);
  var administered = true;
  int? confirmation;
  if (slot?['administrado'] == 1) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ATENÇÃO'),
        content: Text(
          '$name já foi registrado como administrado por ${slot?['actorName']} em ${doseMoment(slot?['administrado_em'])}.\n\nUma nova administração exige confirmação. Corrigir remove a marcação atual e preserva o histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'undo'),
            child: const Text('Corrigir / desmarcar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'another'),
            child: const Text('Registrar outra administração'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    administered = choice != 'undo';
    confirmation = slot?['version'] as int?;
  } else if (!s.online) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sem confirmação da nuvem'),
        content: const Text(
          'O outro cuidador pode já ter administrado esta dose. Confira com ele antes de medicar. O registro ficará pendente até a conexão voltar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Já administrei; registrar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }
  final result = await s.registerDose(
    id: id,
    date: date,
    time: time,
    administered: administered,
    confirmation: confirmation,
    expected: (slot?['version'] as num?)?.toInt() ?? 0,
  );
  if (!context.mounted) return;
  final text = result['status'] == null
      ? 'Registro sincronizado.'
      : result['status'] == 'pending'
      ? 'Registro salvo neste celular, aguardando sincronização. Avise o outro cuidador.'
      : result['status'] == 'duplicate'
      ? 'ATENÇÃO: outra administração foi encontrada. Revise e confirme em Cuidado compartilhado.'
      : 'Os dados mudaram ou houve uma falha. Revise o registro em Cuidado compartilhado.';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Registro da dose'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
