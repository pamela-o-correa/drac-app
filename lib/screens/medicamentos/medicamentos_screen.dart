import 'dart:async';

import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/despertador_service.dart';
import 'medicamento_form_screen.dart';

class MedicamentosScreen extends StatefulWidget {
  const MedicamentosScreen({super.key});

  @override
  State<MedicamentosScreen> createState() => _MedicamentosScreenState();
}

class _MedicamentosScreenState extends State<MedicamentosScreen> {
  bool _carregando = true;
  bool _erro = false;
  int _consulta = 0;
  final Set<int> _alterando = {};

  List<Map<String, dynamic>> _medicamentos = [];

  StreamSubscription<void>? _sharedChanges;
  @override
  void dispose() {
    _sharedChanges?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sharedChanges = SharedService.instance.changes.stream.listen((_) {
      if (mounted) _carregarMedicamentos();
    });

    _carregarMedicamentos();
  }

  Future<void> _carregarMedicamentos() async {
    if (!mounted) return;
    final consulta = ++_consulta;
    setState(() {
      _carregando = true;
      _erro = false;
    });
    try {
      final medicamentos = await DatabaseHelper.instance.buscarMedicamentos();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _medicamentos = medicamentos;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _erro = true;
        _carregando = false;
      });
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? medicamento}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicamentoFormScreen(medicamento: medicamento),
      ),
    );

    if (resultado == true) {
      await _carregarMedicamentos();
    }
  }

  Future<void> _alterarStatus(
    Map<String, dynamic> medicamento,
    bool ativo,
  ) async {
    await _alterar(medicamento['id'] as int, () async {
      await DatabaseHelper.instance.alterarStatusMedicamento(
        medicamento['id'],
        ativo,
      );
    });
  }

  Future<void> _excluir(Map<String, dynamic> medicamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir medicamento?'),
          content: Text(
            'Deseja excluir "${medicamento['nome']}" ? No modo compartilhado, o histórico de ações será preservado. Você também pode desativá-lo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    if (!mounted) return;
    await _alterar(medicamento['id'] as int, () async {
      await DatabaseHelper.instance.excluirMedicamento(
        medicamento['id'],
        expectedVersion: medicamento['_shared_version'] as int?,
      );
    });
  }

  Future<void> _alterar(int id, Future<void> Function() operacao) async {
    if (!_alterando.add(id)) return;
    try {
      await operacao();
      await _atualizarDespertador();
      await _carregarMedicamentos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a alteração. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      _alterando.remove(id);
    }
  }

  Future<void> _atualizarDespertador() async {
    try {
      await DespertadorService.sincronizar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alteração salva, mas não foi possível atualizar o despertador. Confira as configurações.',
            ),
          ),
        );
      }
    }
  }

  Future<String> _buscarHorarios(int medicamentoId) async {
    final horarios = await DatabaseHelper.instance.buscarHorarios(
      medicamentoId,
    );

    if (horarios.isEmpty) {
      return 'Sem horário';
    }

    return horarios.map((item) => item['horario'].toString()).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: const Text('Medicamentos')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      ),

      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro
            ? Center(
                child: TextButton.icon(
                  onPressed: _carregarMedicamentos,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Não foi possível carregar. Tentar novamente',
                  ),
                ),
              )
            : _medicamentos.isEmpty
            ? _estadoVazio()
            : RefreshIndicator(
                onRefresh: _carregarMedicamentos,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
                  itemCount: _medicamentos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final medicamento = _medicamentos[index];

                    return _medicamentoCard(medicamento);
                  },
                ),
              ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 38,
                color: AppColors.primaryDark,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Nenhum medicamento cadastrado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Adicione os medicamentos do Drác para começar o controle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar medicamento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicamentoCard(Map<String, dynamic> medicamento) {
    final ativo = medicamento['ativo'] == 1;

    final dose = medicamento['dose'] ?? '';

    final unidade = medicamento['unidade'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicamento['nome'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '$dose'
                      '${unidade.toString().trim().isEmpty ? '' : ' $unidade'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: ativo,
                onChanged: (valor) {
                  _alterarStatus(medicamento, valor);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          FutureBuilder<String>(
            future: _buscarHorarios(medicamento['id']),
            builder: (context, snapshot) {
              return Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      snapshot.data ?? 'Carregando...',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if ((medicamento['instrucoes'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    medicamento['instrucoes'],
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          const Divider(height: 1),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    _abrirFormulario(medicamento: medicamento);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ),

              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    _excluir(medicamento);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
