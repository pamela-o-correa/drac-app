import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';

class DespertadorService {
  static const channel = MethodChannel('drac/despertador');
  static bool get disponivel =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Map<String, dynamic>> status() async => disponivel
      ? Map<String, dynamic>.from(
          await channel.invokeMapMethod<String, dynamic>('status') ?? {},
        )
      : {'ativo': false, 'permitido': false};

  static Future<void> sharedMode(bool enabled, String database) async {
    if (disponivel) {
      await channel.invokeMethod('compartilhamento', {
        'ativo': enabled,
        'banco': database,
      });
    }
  }

  static Future<void> permissoes() => channel.invokeMethod('permissoes');
  static Future<void> testar() => channel.invokeMethod('testar');
  static Future<void> parar() => channel.invokeMethod('parar');

  static Future<void> sincronizar({bool? ativo}) async {
    if (!disponivel) return;
    final db = await DatabaseHelper.instance.database;
    final doses = await db.rawQuery('''
      SELECT h.id, h.medicamento_id, h.horario, m.nome, m.dose, m.unidade, m.data_inicio, m.data_fim
      FROM horarios_medicamentos h JOIN medicamentos m ON m.id = h.medicamento_id
      WHERE m.ativo = 1
    ''');
    await channel.invokeMethod('sincronizar', {'doses': doses, 'ativo': ativo});
  }
}
