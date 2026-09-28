import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper({this.factory, this.databaseName = 'drac.db'});
  final String databaseName;

  static DatabaseHelper instance = DatabaseHelper();
  final DatabaseFactory? factory;

  Future<Database>? _database;

  Future<Database> get database => _database ??= _abrirBanco();

  Future<Database> _abrirBanco() async {
    try {
      return await _initDatabase();
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final selecionada = factory ?? databaseFactory;
    final databasePath = await selecionada.getDatabasesPath();

    final path = join(databasePath, databaseName);

    return selecionada.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Dados do Drác
    await db.execute('''
      CREATE TABLE drac (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        foto TEXT,
        peso REAL,
        nascimento TEXT,
        observacoes TEXT
      )
    ''');

    // Informações gerais do tratamento
    await db.execute('''
      CREATE TABLE tratamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        veterinario TEXT,
        data_inicio TEXT,
        data_fim TEXT,
        orientacoes TEXT,
        observacoes TEXT,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Medicamentos cadastrados
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        dose TEXT NOT NULL,
        unidade TEXT,
        instrucoes TEXT,
        data_inicio TEXT,
        data_fim TEXT,
        cor INTEGER,
        icone TEXT,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Horários de cada medicamento
    await db.execute('''
      CREATE TABLE horarios_medicamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamento_id INTEGER NOT NULL,
        horario TEXT NOT NULL,

        FOREIGN KEY (medicamento_id)
          REFERENCES medicamentos (id)
          ON DELETE CASCADE
      )
    ''');

    // Registro de cada dose administrada
    await db.execute('''
      CREATE TABLE administracoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamento_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        horario TEXT NOT NULL,
        administrado INTEGER NOT NULL DEFAULT 0,
        observacao TEXT,
        administrado_em TEXT,

        FOREIGN KEY (medicamento_id)
          REFERENCES medicamentos (id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ============================================================
  // DRÁC
  // ============================================================

  Future<int> salvarDrac({
    required String nome,
    String? foto,
    double? peso,
    String? nascimento,
    String? observacoes,
  }) async {
    final db = await database;

    return await db.insert('drac', {
      'nome': nome,
      'foto': foto,
      'peso': peso,
      'nascimento': nascimento,
      'observacoes': observacoes,
    });
  }

  Future<Map<String, dynamic>?> buscarDrac() async {
    final db = await database;

    final resultado = await db.query('drac', limit: 1);

    if (resultado.isEmpty) {
      return null;
    }

    return resultado.first;
  }

  Future<int> atualizarDrac({
    required int id,
    int? expectedVersion,
    required String nome,
    String? foto,
    double? peso,
    String? nascimento,
    String? observacoes,
  }) async {
    final db = await database;

    return await db.update(
      'drac',
      {
        'nome': nome,
        'foto': foto,
        'peso': peso,
        'nascimento': nascimento,
        'observacoes': observacoes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // MEDICAMENTOS
  // ============================================================

  Future<int> adicionarMedicamento({
    required String nome,
    required String dose,
    String? unidade,
    String? instrucoes,
    String? dataInicio,
    String? dataFim,
    int? cor,
    String? icone,
  }) async {
    final db = await database;

    return await db.insert('medicamentos', {
      'nome': nome,
      'dose': dose,
      'unidade': unidade,
      'instrucoes': instrucoes,
      'data_inicio': dataInicio,
      'data_fim': dataFim,
      'cor': cor,
      'icone': icone,
      'ativo': 1,
    });
  }

  Future<List<Map<String, dynamic>>> buscarMedicamentos() async {
    final db = await database;

    return await db.query('medicamentos', orderBy: 'nome ASC');
  }

  Future<List<Map<String, dynamic>>> buscarMedicamentosAtivos() async {
    final db = await database;

    return await db.query(
      'medicamentos',
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'nome ASC',
    );
  }

  Future<int> atualizarMedicamento(int id, Map<String, dynamic> dados) async {
    final db = await database;

    return await db.update(
      'medicamentos',
      dados,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> excluirMedicamento(int id, {int? expectedVersion}) async {
    final db = await database;

    return db.transaction((txn) async {
      // Exclusão atômica também funciona em bancos antigos sem foreign_keys.
      for (final tabela in ['administracoes', 'horarios_medicamentos']) {
        await txn.delete(tabela, where: 'medicamento_id = ?', whereArgs: [id]);
      }
      return txn.delete('medicamentos', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> alterarStatusMedicamento(int id, bool ativo) async {
    final db = await database;

    return await db.update(
      'medicamentos',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // HORÁRIOS
  // ============================================================

  Future<int> adicionarHorario({
    required int medicamentoId,
    required String horario,
  }) async {
    final db = await database;

    return await db.insert('horarios_medicamentos', {
      'medicamento_id': medicamentoId,
      'horario': horario,
    });
  }

  Future<List<Map<String, dynamic>>> buscarHorarios(int medicamentoId) async {
    final db = await database;

    return await db.query(
      'horarios_medicamentos',
      where: 'medicamento_id = ?',
      whereArgs: [medicamentoId],
      orderBy: 'horario ASC',
    );
  }

  Future<int> excluirHorariosDoMedicamento(int medicamentoId) async {
    final db = await database;

    return await db.delete(
      'horarios_medicamentos',
      where: 'medicamento_id = ?',
      whereArgs: [medicamentoId],
    );
  }

  // ============================================================
  // ADMINISTRAÇÕES
  // ============================================================

  Future<int> registrarAdministracao({
    required int medicamentoId,
    required String data,
    required String horario,
    required bool administrado,
    String? observacao,
    String? administradoEm,
  }) async {
    final db = await database;

    return await db.insert('administracoes', {
      'medicamento_id': medicamentoId,
      'data': data,
      'horario': horario,
      'administrado': administrado ? 1 : 0,
      'observacao': observacao,
      'administrado_em': administradoEm,
    });
  }

  Future<List<Map<String, dynamic>>> buscarAdministracoesPorData(
    String data,
  ) async {
    final db = await database;

    return await db.query(
      'administracoes',
      where: 'data = ?',
      whereArgs: [data],
      orderBy: 'horario ASC',
    );
  }

  Future<Map<String, dynamic>?> buscarAdministracaoDaDose({
    required int medicamentoId,
    required String data,
    required String horario,
  }) async {
    final db = await database;

    final resultado = await db.query(
      'administracoes',
      where: '''
        medicamento_id = ?
        AND data = ?
        AND horario = ?
      ''',
      whereArgs: [medicamentoId, data, horario],
      limit: 1,
    );

    if (resultado.isEmpty) {
      return null;
    }

    return resultado.first;
  }

  Future<void> salvarStatusDaDose({
    required int medicamentoId,
    required String data,
    required String horario,
    required bool administrado,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      const where = 'medicamento_id = ? AND data = ? AND horario = ?';
      final args = [medicamentoId, data, horario];
      final existentes = await txn.query(
        'administracoes',
        where: where,
        whereArgs: args,
      );
      final valores = <String, Object?>{
        'administrado': administrado ? 1 : 0,
        'administrado_em': administrado
            ? DateTime.now().toIso8601String()
            : null,
      };
      if (existentes.isEmpty) {
        await txn.insert('administracoes', {
          ...valores,
          'medicamento_id': medicamentoId,
          'data': data,
          'horario': horario,
        });
      } else if (!administrado ||
          !existentes.any((row) => row['administrado'] == 1)) {
        await txn.update(
          'administracoes',
          valores,
          where: where,
          whereArgs: args,
        );
      }
    });
  }

  // ============================================================
  // TRATAMENTOS
  // ============================================================

  Future<int> adicionarTratamento({
    required String titulo,
    String? veterinario,
    String? dataInicio,
    String? dataFim,
    String? orientacoes,
    String? observacoes,
    bool ativo = true,
  }) async {
    final db = await database;

    return await db.insert('tratamentos', {
      'titulo': titulo,
      'veterinario': veterinario,
      'data_inicio': dataInicio,
      'data_fim': dataFim,
      'orientacoes': orientacoes,
      'observacoes': observacoes,
      'ativo': ativo ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> buscarTratamentos() async {
    final db = await database;

    return await db.query('tratamentos', orderBy: 'id DESC');
  }

  Future<int> atualizarTratamento(
    int id,
    Map<String, dynamic> dados, {
    int? expectedVersion,
  }) async {
    final db = await database;

    return await db.update(
      'tratamentos',
      dados,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // FECHAR BANCO
  // ============================================================

  Future<int> salvarMedicamentoCompleto({
    int? id,
    required Map<String, dynamic> dados,
    required List<String> horarios,
    int? expectedVersion,
  }) async {
    return (await database).transaction((tx) async {
      final recordId =
          id ?? await tx.insert('medicamentos', {...dados, 'ativo': 1});
      if (id != null) {
        final count = await tx.update(
          'medicamentos',
          dados,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count != 1) throw StateError('Medicamento não encontrado');
        await tx.delete(
          'horarios_medicamentos',
          where: 'medicamento_id = ?',
          whereArgs: [id],
        );
      }
      for (final horario in horarios) {
        await tx.insert('horarios_medicamentos', {
          'medicamento_id': recordId,
          'horario': horario,
        });
      }
      return recordId;
    });
  }

  Future<void> fecharBanco() async {
    final abertura = _database;
    if (abertura == null) return;
    final db = await abertura;
    await db.close();
    _database = null;
  }
}
