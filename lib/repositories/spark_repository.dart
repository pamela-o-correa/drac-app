import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Spark: transactions execute in the client; Security Rules validate all writes.
class SparkRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  SparkRepository(this.db, this.auth);
  static const tables = [
    'drac',
    'tratamentos',
    'medicamentos',
    'horarios_medicamentos',
  ];
  String randomId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  User get user {
    final u = auth.currentUser;
    if (u == null || !u.emailVerified) {
      throw StateError('Entre na conta e confirme seu e-mail.');
    }
    return u;
  }

  Map<String, dynamic> get actor => {
    'uid': user.uid,
    'name': user.displayName ?? user.email ?? 'Usuário',
  };
  DocumentReference<Map<String, dynamic>> stateRef(String g) =>
      db.doc('groups/$g/pets/drac');
  String key(int id, String date, String time) =>
      '${id}_${date.replaceAll('/', '-')}_${time.replaceAll(':', '-')}';
  Map<String, dynamic> clone(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  void prepare(Map<String, dynamic> s) {
    s['medicationsById'] = {
      for (final m in s['medicamentos'] as List) '${m['id']}': m,
    };
    for (final t in tables) {
      if ((s[t] as List).length > 500) {
        throw StateError(
          'Limite de cadastros desta versão de estudo atingido.',
        );
      }
    }
    if (utf8.encode(jsonEncode(s)).length > 200000) {
      throw StateError('Cadastros excedem o limite seguro desta versão.');
    }
  }

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> args,
  ) async {
    user;
    switch (method) {
      case 'createGroup':
        return createGroup(Map<String, dynamic>.from(args['state'] as Map));
      case 'importLegacy':
        for (final row in args['rows'] as List) {
          await importRow(
            args['groupId'] as String,
            Map<String, dynamic>.from(row as Map),
          );
        }
        return {'ok': true};
      case 'finishMigration':
        await db.runTransaction((tx) async {
          final ref = db.doc('groups/${args['groupId']}');
          final snap = await tx.get(ref);
          if (snap.data()?['migrationOpen'] == true) {
            tx.update(ref, {'migrationOpen': false});
          }
        });
        return {'ok': true};
      case 'createInvite':
        return invite(args['groupId'] as String);
      case 'acceptInvite':
        return join(args['code'] as String);
      case 'mutate':
        return mutate(
          args['groupId'] as String,
          Map<String, dynamic>.from(args['command'] as Map),
        );
      default:
        throw StateError('Operação não disponível no plano gratuito.');
    }
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> initial) async {
    final profile = db.doc('users/${user.uid}'),
        group = db.collection('groups').doc();
    return db.runTransaction((tx) async {
      final old = await tx.get(profile);
      if (old.exists) return {'groupId': old.data()!['groupId']};
      final state = clone(initial);
      state['version'] = 1;
      state['lastEventId'] = 'initial';
      prepare(state);
      tx.set(group, {
        'owner': user.uid,
        'members': [user.uid],
        'migrationOpen': true,
        'inviteCode': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(profile, {'groupId': group.id, 'name': actor['name']});
      tx.set(stateRef(group.id), state);
      return {'groupId': group.id};
    });
  }

  Future<Map<String, dynamic>> invite(String g) async {
    final code = randomId();
    await db.runTransaction((tx) async {
      final group = await tx.get(db.doc('groups/$g'));
      if (group.data()?['owner'] != user.uid ||
          group.data()?['migrationOpen'] == true) {
        throw StateError(
          'Somente o responsável pode convidar após concluir a importação.',
        );
      }
      final old = group.data()?['inviteCode'] as String?;
      if (old != null && old.isNotEmpty) tx.delete(db.doc('invites/$old'));
      tx.set(db.doc('invites/$code'), {
        'groupId': g,
        'owner': user.uid,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 23, minutes: 55)),
        ),
      });
      tx.update(db.doc('groups/$g'), {'inviteCode': code});
    });
    return {'code': code};
  }

  Future<Map<String, dynamic>> join(String code) async {
    code = code.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(code)) {
      throw StateError('Código inválido.');
    }
    return db.runTransaction((tx) async {
      final invitation = await tx.get(db.doc('invites/$code'));
      final profile = db.doc('users/${user.uid}');
      final old = await tx.get(profile);
      if (old.exists) throw StateError('Esta conta já possui um grupo.');
      if (!invitation.exists ||
          (invitation.data()!['expiresAt'] as Timestamp).toDate().isBefore(
            DateTime.now(),
          )) {
        throw StateError('Convite usado ou expirado.');
      }
      final g = invitation.data()!['groupId'] as String;
      // No permission to read the group before joining. Rules validate the atomic union.
      tx.update(db.doc('groups/$g'), {
        'members': FieldValue.arrayUnion([user.uid]),
      });
      tx.set(profile, {
        'groupId': g,
        'name': actor['name'],
        'inviteCode': code,
      });
      tx.delete(invitation.reference);
      return {'groupId': g};
    });
  }

  Future<void> importRow(String g, Map<String, dynamic> r) async {
    final eventRef = db.doc('groups/$g/events/legacy-${r['id']}');
    final slotRef = db.doc(
      'groups/$g/slots/${key(r['medicamento_id'] as int, r['data'] as String, r['horario'] as String)}',
    );
    await db.runTransaction((tx) async {
      final event = await tx.get(eventRef);
      if (event.exists) return;
      final old = await tx.get(slotRef);
      final config = await tx.get(stateRef(g));
      final med =
          (config.data()!['medicationsById'] as Map)['${r['medicamento_id']}']
              as Map?;
      final values = <String, dynamic>{
        'medicamento_id': r['medicamento_id'],
        'data': r['data'],
        'horario': r['horario'],
        'administrado': r['administrado'] == 1 ? 1 : 0,
        'administrado_em': r['administrado_em'],
        'actorUid': null,
        'actorName': 'Registro local anterior — responsável desconhecido',
        'medicationName': med?['nome'] ?? 'Medicamento ${r['medicamento_id']}',
        'dose': 'não registrada no histórico antigo',
        'unidade': '',
        'version': (old.data()?['version'] as int? ?? 0) + 1,
        'lastEventId': eventRef.id,
        'serverAt': FieldValue.serverTimestamp(),
      };
      final writeSlot =
          !old.exists ||
          (r['administrado'] == 1 && old.data()?['administrado'] != 1);
      tx.set(eventRef, {
        'type': 'legacy',
        'actor': {'uid': null, 'name': values['actorName']},
        'importedBy': user.uid,
        'serverAt': FieldValue.serverTimestamp(),
        'clientAt': r['administrado_em'],
        'summary':
            'Registro local importado: ${values['medicationName']} — ${r['data']} às ${r['horario']}',
        'before': old.data(),
        'after': values,
        'slotId': slotRef.id,
        'writesSlot': writeSlot,
      });
      if (writeSlot) tx.set(slotRef, values);
    });
  }

  Future<Map<String, dynamic>> mutate(String g, Map<String, dynamic> c) async {
    // Rules can reject a stale preimage before Firestore retries contention.
    // Retry with the SAME reviewed versions and operation ID: never approve silently.
    for (var attempt = 0; ; attempt++) {
      try {
        return await _mutate(g, c);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt >= 2) rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _mutate(String g, Map<String, dynamic> c) async {
    final op = c['operationId'] as String,
        eventRef = db.doc('groups/$g/events/$op');
    return db.runTransaction((tx) async {
      final event = await tx.get(eventRef);
      if (event.exists) {
        if ((event.data()!['actor'] as Map)['uid'] != user.uid) {
          throw StateError('Operação de outra pessoa.');
        }
        return {'ok': true, 'id': event.data()?['targetId']};
      }
      final stateDoc = await tx.get(stateRef(g)), state = stateDoc.data()!;
      if (c['action'] == 'administer' || c['action'] == 'undo') {
        final slotRef = db.doc(
          'groups/$g/slots/${key(c['medicationId'] as int, c['date'] as String, c['time'] as String)}',
        );
        final snap = await tx.get(slotRef), before = snap.data();
        final version = before?['version'] ?? 0;
        final duplicate =
            c['action'] == 'administer' && before?['administrado'] == 1;
        if (c['expected'] != version ||
            (duplicate && c['confirmedVersion'] != version)) {
          return {'status': duplicate ? 'duplicate' : 'conflict'};
        }
        if (c['medicationVersion'] != state['version']) {
          return {
            'status': 'conflict',
            'message': 'O tratamento mudou. Confira os dados atuais antes de confirmar.',
          };
        }
        final med =
            (state['medicationsById'] as Map)['${c['medicationId']}'] as Map?;
        if (med == null) throw StateError('Medicamento excluído.');
        final after = {
          'medicamento_id': c['medicationId'],
          'data': c['date'],
          'horario': c['time'],
          'administrado': c['action'] == 'administer' ? 1 : 0,
          'administrado_em': c['clientAt'],
          'actorUid': user.uid,
          'actorName': actor['name'],
          'version': (version as int) + 1,
          'medicationName': med['nome'],
          'dose': med['dose'],
          'unidade': med['unidade'] ?? '',
          'serverAt': FieldValue.serverTimestamp(),
          'lastEventId': op,
        };
        tx.set(slotRef, after);
        tx.set(eventRef, {
          'type': c['action'],
          'actor': actor,
          'serverAt': FieldValue.serverTimestamp(),
          'clientAt': c['clientAt'],
          'summary':
              '${c['action'] == 'administer' ? 'Administrou' : 'Corrigiu o registro de'} ${med['nome']} — dose prevista para ${c['date']} às ${c['time']}',
          'before': before,
          'after': after,
          'slotId': slotRef.id,
          'confirmedVersion': c['confirmedVersion'],
          'medicationVersion': state['version'],
        });
        return {'ok': true};
      }
      if (c['expected'] != state['version']) {
        return {
          'status': 'conflict',
          'message':
              'Outra pessoa alterou os dados. Reabra a tela antes de salvar.',
        };
      }
      final table = c['table'] as String;
      if (!['drac', 'tratamentos', 'medicamentos'].contains(table)) {
        throw StateError('Cadastro inválido.');
      }
      final next = clone(state);
      var nextId =
          (state['nextId'] as int?) ??
          (tables
                  .expand((t) => (state[t] as List).map((r) => r['id'] as int))
                  .fold(0, max) +
              1);
      final id = (c['id'] as int?) ?? nextId++;
      final rows = next[table] as List;
      final before = rows.where((r) => r['id'] == id).firstOrNull as Map?;
      if (c['id'] != null && before == null) {
        throw StateError('Cadastro não encontrado.');
      }
      rows.removeWhere((r) => r['id'] == id);
      if (c['action'] == 'save') {
        final record = <String, dynamic>{
          ...?before?.cast<String, dynamic>(),
          ...Map<String, dynamic>.from(c['values'] as Map),
          'id': id,
        };
        if (table != 'drac') record.putIfAbsent('ativo', () => 1);
        rows.add(record);
        if (table == 'medicamentos' && c['times'] != null) {
          (next['horarios_medicamentos'] as List).removeWhere(
            (h) => h['medicamento_id'] == id,
          );
          for (final time in (c['times'] as List).toSet()) {
            (next['horarios_medicamentos'] as List).add({
              'id': nextId++,
              'medicamento_id': id,
              'horario': time,
            });
          }
        }
      } else if (c['action'] == 'delete' && table == 'medicamentos') {
        (next['horarios_medicamentos'] as List).removeWhere(
          (h) => h['medicamento_id'] == id,
        );
      } else {
        throw StateError('Operação inválida.');
      }
      next['nextId'] = nextId;
      next['version'] = (state['version'] as int) + 1;
      next['lastEventId'] = op;
      prepare(next);
      final changedName =
          (c['values'] as Map?)?['nome'] ??
          before?['nome'] ??
          (c['values'] as Map?)?['titulo'] ??
          'perfil/tratamento';
      tx.set(stateRef(g), next);
      tx.set(eventRef, {
        'type': c['action'],
        'actor': actor,
        'serverAt': FieldValue.serverTimestamp(),
        'summary':
            '${c['action'] == 'delete'
                ? 'Excluiu'
                : before == null
                ? 'Adicionou'
                : 'Alterou'} $changedName',
        'before': state,
        'after': next,
        'targetId': id,
      });
      return {'ok': true, 'id': id};
    });
  }
}
