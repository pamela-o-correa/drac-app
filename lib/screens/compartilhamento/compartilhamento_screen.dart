import '../../services/dose_confirmation.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/shared_service.dart';

class CompartilhamentoScreen extends StatefulWidget {
  const CompartilhamentoScreen({super.key});
  @override
  State<CompartilhamentoScreen> createState() => _CompartilhamentoScreenState();
}

class _CompartilhamentoScreenState extends State<CompartilhamentoScreen> {
  final s = SharedService.instance;
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool busy = false;
  String? message, invite;
  @override
  void initState() {
    super.initState();
    s.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(refresh);
    for (final c in [name, email, password, code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await task();
    } catch (e) {
      message = e is FirebaseAuthException
          ? (e.message ?? 'Não foi possível entrar.')
          : e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(String label, Future<void> Function() action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: OutlinedButton(
      onPressed: busy ? null : () => run(action),
      child: Text(label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = s.configured ? s.auth.currentUser : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuidado compartilhado')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Plano gratuito Spark: cada pessoa usa sua própria conta. Crie o grupo no celular que tem os dados atuais e convide a outra pessoa. Alterações aparecem com o app aberto; push com o app fechado não está habilitado.',
          ),
          const SizedBox(height: 16),
          if (!s.configured)
            const Text(
              'Firebase ainda não configurado. Os medicamentos locais continuam disponíveis. Siga o guia CONFIGURACAO_FIREBASE.md do projeto.',
            ),
          if (s.configured && user == null) ...[
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Seu nome (para criar conta)',
              ),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha (mínimo 8 caracteres)',
              ),
            ),
            button('Entrar', () async {
              await s.auth.signInWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
              await s.connect();
            }),
            button('Criar conta', () async {
              if (name.text.trim().isEmpty || password.text.length < 8) {
                throw StateError(
                  'Informe seu nome e uma senha de pelo menos 8 caracteres.',
                );
              }
              final result = await s.auth.createUserWithEmailAndPassword(
                email: email.text.trim(),
                password: password.text,
              );
              await result.user!.updateDisplayName(name.text.trim());
              await result.user!.sendEmailVerification();
              message = 'Enviamos a confirmação para seu e-mail.';
            }),
            button('Redefinir senha', () async {
              await s.auth.sendPasswordResetEmail(email: email.text.trim());
              message = 'Confira seu e-mail para redefinir a senha.';
            }),
          ],
          if (user != null) ...[
            Text('Conta: ${user.displayName ?? user.email}'),
            if (!user.emailVerified) ...[
              const Text(
                'Abra o link enviado ao seu e-mail antes de vincular um grupo.',
              ),
              button('Já confirmei meu e-mail', () async {
                await user.reload();
                await s.auth.currentUser!.getIdToken(true);
                await s.connect();
              }),
              button('Reenviar e-mail de confirmação', () async {
                await user.sendEmailVerification();
                message = 'E-mail enviado.';
              }),
            ] else ...[
              if (!s.active) ...[
                button('Criar grupo e importar dados deste celular', () async {
                  await s.createGroup();
                  message =
                      'Dados importados. O banco original foi preservado.';
                }),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Código de convite',
                  ),
                ),
                button('Entrar no grupo pelo convite', () async {
                  await s.join(code.text);
                  message = 'Grupo vinculado. Seus antigos dados locais permanecem separados.';
                }),
                button('Reconectar ao meu grupo', s.connect),
              ] else ...[
                const Text(
                  'Grupo do Drác vinculado. As alterações aparecem automaticamente nos aparelhos conectados.',
                ),
                Text(
                  s.online ? 'Conectado à sincronização' : 'Conexão não confirmada; confira os registros pendentes.',
                ),
                button('Gerar convite (responsável pelo grupo)', () async {
                  invite = await s.invite();
                }),
                if (invite != null) ...[
                  SelectableText(invite!),
                  const Text(
                    'Uso único, válido por aproximadamente 24 horas. Um novo código invalida o anterior. Compartilhe somente com a pessoa autorizada.',
                  ),
                  button('Copiar convite', () async {
                    await Clipboard.setData(ClipboardData(text: invite!));
                    message = 'Código copiado.';
                  }),
                ],
                button(
                  'Retomar importação interrompida (celular original)',
                  () async {
                    await s.createGroup();
                    message = 'Importação concluída.';
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Registros pendentes: ${s.pending}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Enquanto houver pendências, avise a outra pessoa antes de administrar. Uma confirmação local não garante que o outro aparelho já recebeu a informação.',
                ),
                button('Tentar sincronizar agora', s.flush),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: s.pendingRows(),
                  builder: (context, snapshot) => Column(
                    children: [
                      for (final row
                          in snapshot.data ?? <Map<String, dynamic>>[])
                        _pending(row),
                    ],
                  ),
                ),
              ],
            ],
            button('Sair da conta', s.signOut),
          ],
          if (busy) const Center(child: CircularProgressIndicator()),
          if (message != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(message!)),
          if (s.error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(s.error!)),
        ],
      ),
    );
  }

  Widget _pending(Map<String, dynamic> row) {
    final c = Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
    final current = s.slot(c['medicationId'], c['date'], c['time']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${current?['medicationName'] ?? 'Medicamento ${c['medicationId']}'} • ${c['date']} ${c['time']}',
            ),
            Text(
              'Situação: ${{'pending': 'Aguardando conexão', 'duplicate': 'Possível dose duplicada', 'conflict': 'Dados alterados por outro cuidador', 'error': 'Não foi possível sincronizar'}[row['status']] ?? 'Aguardando revisão'} • ação: ${c['action'] == 'administer' ? 'administração' : 'correção'}',
            ),
            if (current?['administrado'] == 1)
              Text(
                'ATENÇÃO: registrado por ${current?['actorName']} em ${doseMoment(current?['administrado_em'])}.',
              ),
            if (row['response'] != null)
              Text(
                (jsonDecode(row['response'] as String) as Map)['message']
                        ?.toString() ??
                    'Confira o registro atual antes de confirmar esta ação.',
              ),
            if (row['status'] != 'pending')
              button('Revisar e confirmar este registro', () async {
                final reviewedVersion =
                    (current?['version'] as num?)?.toInt() ?? 0;
                final reviewedMedicationVersion = s.revision;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ATENÇÃO'),
                    content: Text(
                      'Confira o medicamento, a dose e o tratamento atual. ${c['action'] == 'undo'
                          ? 'Confirma a correção/desmarcação deste horário, preservando o histórico?'
                          : current?['administrado'] == 1
                          ? 'Já existe administração por ${current?['actorName']} em ${doseMoment(current?['administrado_em'])}. Este registro representa outra administração real?'
                          : 'Confirma que esta ação corresponde ao que aconteceu?'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirmar registro'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await s.resolve(
                    row,
                    retry: true,
                    reviewedVersion: reviewedVersion,
                    reviewedMedicationVersion: reviewedMedicationVersion,
                  );
                }
              }),
            if (row['status'] != 'pending')
              button('Descartar registro pendente', () async {
                await s.resolve(row, retry: false);
              }),
          ],
        ),
      ),
    );
  }
}
