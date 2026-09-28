import 'package:flutter/material.dart';

import '../services/shared_service.dart';
import '../screens/compartilhamento/compartilhamento_screen.dart';

class SharedStatus extends StatelessWidget {
  const SharedStatus({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SharedService.instance,
    builder: (context, _) {
      final s = SharedService.instance;
      return Material(
        color: s.pending > 0
            ? Colors.amber.shade100
            : Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: ListTile(
            dense: true,
            leading: Icon(s.active ? Icons.cloud_sync : Icons.people_outline),
            title: Text(
              s.active
                  ? s.pending > 0
                        ? '${s.pending} registro(s) pendente(s) — confira antes de administrar'
                        : s.online
                        ? 'Cuidado compartilhado'
                        : 'Dados locais — conexão não confirmada'
                  : 'Somente neste aparelho • configurar compartilhamento',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompartilhamentoScreen()),
            ),
          ),
        ),
      );
    },
  );
}
