import '../repositories/spark_repository.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../database/shared_database.dart';
import 'despertador_service.dart';

class SharedService extends ChangeNotifier {
  SharedService._();
  static final instance = SharedService._();
  bool configured = false, loading = false, active = false, online = false;
  String? groupId, error;
  int revision = 0, pending = 0;
  final changes = StreamController<void>.broadcast();
  final messages = StreamController<String>.broadcast();
  final local = DatabaseHelper();
  SharedDatabase? shared;
  StreamSubscription<dynamic>? _stateSub, _slotsSub, _eventsSub;
  Timer? _retry;
  Future<void> _projection = Future.value();
  bool _flushing = false, _writing = false;
  int _session = 0;
  final Map<String, Map<String, dynamic>> slots = {};
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  SparkRepository get repository => SparkRepository(firestore, auth);
  String operationId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      configured = true;
      if (auth.currentUser != null && auth.currentUser!.emailVerified) {
        await connect();
      }
    } catch (e) {
      error = 'Compartilhamento indisponível. Confira a configuração Firebase e a conexão.';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    return repository.call(name, data).timeout(const Duration(seconds: 20));
  }

  Future<void> connect() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final user = auth.currentUser;
      if (user == null || !user.emailVerified) return;
      final snap = await firestore.doc('users/${user.uid}').get();
      final g = snap.data()?['groupId'] as String?;
      if (g == null) return;
      if (groupId == g && active) return;
      await _stop();
      final generation = ++_session;
      groupId = g;
      final db = SharedDatabase(this, 'shared_${user.uid}_$g.db');
      shared = db;
      await db.prepare();
      DatabaseHelper.instance = db;
      active = true;
      await DespertadorService.sharedMode(true, db.databaseName);
      _stateSub = firestore
          .doc('groups/$g/pets/drac')
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snap) {
              if (generation != _session) return;
              online = !snap.metadata.isFromCache;
              if (!snap.exists) return;
              _projection = _projection
                  .then((_) async {
                    if (generation != _session) return;
                    await db.projectState(snap.data()!);
                    revision = (snap.data()!['version'] as num).toInt();
                    changes.add(null);
                    notifyListeners();
                    await _alarms();
                  })
                  .catchError((Object e) {
                    error = 'Falha ao atualizar os cadastros: $e';
                    notifyListeners();
                  });
            },
            onError: (Object e) {
              online = false;
              error = 'Acesso à sincronização interrompido. Entre novamente e confira seu grupo.';
              notifyListeners();
            },
          );
      _slotsSub = firestore
          .collection('groups/$g/slots')
          .snapshots()
          .listen(
            (snap) {
              _projection = _projection
                  .then((_) async {
                    if (generation != _session) return;
                    slots.clear();
                    for (final doc in snap.docs) {
                      slots[doc.id] = doc.data();
                    }
                    await db.projectSlots(slots.values.toList());
                    changes.add(null);
                    notifyListeners();
                  })
                  .catchError((Object e) {
                    error = 'Falha ao atualizar doses: $e';
                    notifyListeners();
                  });
            },
            onError: (Object e) {
              online = false;
              error = 'Não foi possível conferir as doses na nuvem.';
              notifyListeners();
            },
          );
      final listeningSince = Timestamp.now();
      _eventsSub = firestore
          .collection('groups/$g/events')
          .where('serverAt', isGreaterThan: listeningSince)
          .orderBy('serverAt')
          .limitToLast(20)
          .snapshots()
          .listen(
            (snapshot) {
              if (generation != _session) return;
              for (final change in snapshot.docChanges) {
                final event = change.doc.data();
                if (change.type == DocumentChangeType.added &&
                    event?['actor']?['uid'] != user.uid &&
                    event?['type'] != 'legacy') {
                  messages.add(
                    '${event?['actor']?['name']}: ${event?['summary']}',
                  );
                }
              }
            },
            onError: (Object _) {
              /* Main state streams still report connectivity. */
            },
          );
      _retry = Timer.periodic(const Duration(seconds: 20), (_) => flush());
      unawaited(flush());
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _alarms() async {
    try {
      await DespertadorService.sincronizar();
    } catch (_) {
      error = 'Dados atualizados, mas confira as permissões do despertador.';
      notifyListeners();
    }
  }

  Future<void> createGroup() async {
    final db = await local.database;
    final state = <String, dynamic>{};
    for (final t in [
      'drac',
      'tratamentos',
      'medicamentos',
      'horarios_medicamentos',
    ]) {
      state[t] = await db.query(t);
    }
    final result = await call('createGroup', {'state': state});
    final g = result['groupId'];
    // Stable legacy IDs make a failed/interrupted import safe to resume.
    final rows = await db.query('administracoes', orderBy: 'id ASC');
    for (var i = 0; i < rows.length; i += 100) {
      await call('importLegacy', {
        'groupId': g,
        'rows': rows.sublist(i, min(i + 100, rows.length)),
      });
    }
    await call('finishMigration', {'groupId': g});
    await connect();
  }

  Future<void> join(String code) async {
    await call('acceptInvite', {'code': code.trim()});
    await connect();
  }

  Future<String> invite() async =>
      (await call('createInvite', {'groupId': groupId}))['code'] as String;

  Future<Map<String, dynamic>> mutate(Map<String, dynamic> command) async {
    final response = await call('mutate', {
      'groupId': groupId,
      'command': {'operationId': operationId(), ...command},
    });
    if (response['status'] != null) {
      throw StateError(
        response['message']?.toString() ??
            'Os dados mudaram. Reabra a tela e confira antes de salvar.',
      );
    }
    return response;
  }

  static String slotKey(int id, String date, String time) =>
      '${id}_${date.replaceAll('/', '-')}_${time.replaceAll(':', '-')}';
  Map<String, dynamic>? slot(int id, String date, String time) =>
      slots[slotKey(id, date, time)];
  Future<Map<String, dynamic>> registerDose({
    required int id,
    required String date,
    required String time,
    required bool administered,
    int? confirmation,
    int? expected,
  }) async {
    if (_writing) throw StateError('Aguarde o registro em andamento.');
    _writing = true;
    try {
      final current = slot(id, date, time);
      final command = <String, dynamic>{
        'operationId': operationId(),
        'action': administered ? 'administer' : 'undo',
        'medicationId': id,
        'date': date,
        'time': time,
        'expected': expected ?? current?['version'] ?? 0,
        'confirmedVersion': confirmation,
        'medicationVersion': revision,
        'clientAt': DateTime.now().toUtc().toIso8601String(),
      };
      final db = await shared!.database;
      final existing = await db.query(
        'outbox',
        where: 'slot_key = ?',
        whereArgs: [slotKey(id, date, time)],
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Esta dose já tem uma ação pendente. Resolva-a em Compartilhamento.',
        );
      }
      await db.insert('outbox', {
        'id': command['operationId'],
        'slot_key': slotKey(id, date, time),
        'payload': jsonEncode(command),
        'status': 'pending',
      });
      await _count();
      final result = await _send(command);
      await _count();
      return result;
    } finally {
      _writing = false;
    }
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> command) async {
    final db = await shared!.database;
    try {
      final response = await call('mutate', {
        'groupId': groupId,
        'command': command,
      });
      if (response['status'] == null) {
        await db.delete(
          'outbox',
          where: 'id = ?',
          whereArgs: [command['operationId']],
        );
        online = true;
      } else {
        await db.update(
          'outbox',
          {'status': response['status'], 'response': jsonEncode(response)},
          where: 'id = ?',
          whereArgs: [command['operationId']],
        );
      }
      return response;
    } on FirebaseException catch (e) {
      if ([
        'unavailable',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
        'aborted',
      ].contains(e.code)) {
        online = false;
        return {'status': 'pending'};
      }
      await db.update(
        'outbox',
        {
          'status': 'error',
          'response': jsonEncode({'message': e.message}),
        },
        where: 'id = ?',
        whereArgs: [command['operationId']],
      );
      return {'status': 'error', 'message': e.message};
    } on StateError catch (e) {
      await db.update(
        'outbox',
        {
          'status': 'error',
          'response': jsonEncode({'message': e.message}),
        },
        where: 'id = ?',
        whereArgs: [command['operationId']],
      );
      return {'status': 'error', 'message': e.message};
    } catch (_) {
      online = false;
      return {'status': 'pending'};
    }
  }

  Future<void> _count() async {
    pending = (await pendingRows()).length;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> pendingRows() async =>
      shared == null ? [] : await (await shared!.database).query('outbox');
  Future<void> flush() async {
    if (!active || _flushing) return;
    _flushing = true;
    try {
      for (final row in await pendingRows()) {
        if (row['status'] == 'pending') {
          await _send(
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String)),
          );
        }
      }
      await _count();
    } catch (_) {
      error = 'Registros locais aguardando nova tentativa.';
      notifyListeners();
    } finally {
      _flushing = false;
    }
  }

  Future<void> resolve(
    Map<String, dynamic> row, {
    required bool retry,
    int? reviewedVersion,
    int? reviewedMedicationVersion,
  }) async {
    if (_flushing) {
      throw StateError('Aguarde a tentativa de sincronização terminar.');
    }
    final db = await shared!.database;
    if (retry) {
      final command = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String),
      );
      // A newer event arriving while the dialog is open invalidates this review.
      if (reviewedVersion == null || reviewedMedicationVersion == null) {
        throw StateError('Revise os dados antes de confirmar.');
      }
      command['expected'] = reviewedVersion;
      command['confirmedVersion'] = reviewedVersion;
      command['medicationVersion'] = reviewedMedicationVersion;
      await db.update(
        'outbox',
        {'payload': jsonEncode(command), 'status': 'pending'},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      await flush();
    } else {
      await db.delete('outbox', where: 'id = ?', whereArgs: [row['id']]);
      await _count();
    }
  }

  Future<void> _stop() async {
    _session++;
    _retry?.cancel();
    await _stateSub?.cancel();
    await _slotsSub?.cancel();
    await _eventsSub?.cancel();
    await _projection;
  }

  Future<void> signOut() async {
    if (_writing || _flushing || pending > 0) {
      throw StateError('Resolva os registros pendentes antes de sair.');
    }
    await _stop();
    await auth.signOut();
    active = false;
    online = false;
    groupId = null;
    slots.clear();
    revision = 0;
    DatabaseHelper.instance = local;
    await DespertadorService.sharedMode(false, 'drac.db');
    await _alarms();
    changes.add(null);
    notifyListeners();
  }
}
