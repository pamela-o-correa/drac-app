import '../../services/audit_details.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/shared_service.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});
  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  int limit = 100;
  String format(dynamic value) {
    final date = value is Timestamp
        ? value.toDate().toLocal()
        : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Horário não informado';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = SharedService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de ações')),
      body: !s.active
          ? const Center(
              child: Text(
                'Vincule uma conta para consultar o histórico compartilhado.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: s.firestore
                  .collection('groups/${s.groupId}/events')
                  .orderBy('serverAt', descending: true)
                  .limit(limit)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text(
                      'Não foi possível carregar o histórico. Confira sua conexão e acesso ao grupo.',
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (snap.data!.metadata.isFromCache)
                      const Text(
                        'Histórico salvo neste aparelho; pode estar desatualizado.',
                      ),
                    for (final doc in docs)
                      Builder(
                        builder: (context) {
                          final e = doc.data(), after = e['after'];
                          final differences = auditDetails(e);
                          return Card(
                            child: ListTile(
                              title: Text(e['summary'] ?? 'Ação'),
                              subtitle: Text(
                                [
                                  '${e['actor']?['name'] ?? 'Responsável desconhecido'} • ${format(e['clientAt'] ?? e['serverAt'])}',
                                  if (e['clientAt'] != null)
                                    'Sincronizado em ${format(e['serverAt'])}',
                                  if (after is Map && after['dose'] != null)
                                    'Dose: ${after['dose']} ${after['unidade'] ?? ''}',
                                  ...differences,
                                ].join('\n'),
                              ),
                            ),
                          );
                        },
                      ),
                    if (docs.length >= limit)
                      TextButton(
                        onPressed: () => setState(() => limit += 100),
                        child: const Text('Carregar mais'),
                      ),
                    if (docs.isEmpty) const Text('Nenhuma ação registrada.'),
                  ],
                );
              },
            ),
    );
  }
}
