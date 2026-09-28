import '../../services/dose_confirmation.dart';

import 'dart:async';

import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/agenda_service.dart';
import '../../database/database_helper.dart';
import '../../widgets/date_selector_card.dart';
import '../../widgets/dose_card.dart';
import '../../widgets/drac_header.dart';
import '../../widgets/progress_card.dart';
import '../drac/drac_screen.dart';
import '../medicamentos/medicamentos_screen.dart';
import '../tratamento/tratamento_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _diaSelecionado = DateTime.now();

  bool _carregando = true;
  bool _erro = false;
  int _consulta = 0;
  final Set<String> _salvandoDoses = {};

  List<_DoseDoDia> _doses = [];

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
      if (mounted) _carregarDoses();
    });

    _carregarDoses();
  }

  // ============================================================
  // CARREGAMENTO
  // ============================================================

  Future<void> _carregarDoses() async {
    if (!mounted) return;
    final consulta = ++_consulta;
    final periodo = _diaSelecionado;
    setState(() {
      _carregando = true;
      _erro = false;
      _doses = [];
    });
    try {
      final agenda = await AgendaService.carregar(periodo, periodo);
      final resultado = agenda
          .dosesDoDia(periodo, apenasAtivos: true)
          .map(
            (r) => _DoseDoDia(
              medicamentoId: r['id'] as int,
              nome: r['nome'].toString(),
              horario: r['horario'].toString(),
              descricao: _descricaoMedicamento(r) + _responsavel(r, periodo),
              administrado: r['administrado'] as bool,
            ),
          )
          .toList();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _doses = resultado;
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

  // ============================================================
  // MARCAR / DESMARCAR
  // ============================================================

  Future<void> _alternarDose(int index) async {
    if (_carregando || index >= _doses.length) return;
    final dose = _doses[index];
    final data = AgendaService.formatarData(_diaSelecionado);
    final chave = '${dose.medicamentoId}|$data|${dose.horario}';
    if (!_salvandoDoses.add(chave)) return;
    try {
      if (SharedService.instance.active) {
        await confirmSharedDose(
          context,
          id: dose.medicamentoId,
          date: data,
          time: dose.horario,
          name: dose.nome,
        );
        return;
      }
      await DatabaseHelper.instance.salvarStatusDaDose(
        medicamentoId: dose.medicamentoId,
        data: data,
        horario: dose.horario,
        administrado: !dose.administrado,
      );
      if (mounted && AgendaService.formatarData(_diaSelecionado) == data) {
        await _carregarDoses();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a dose. Tente novamente.'),
          ),
        );
      }
    } finally {
      _salvandoDoses.remove(chave);
    }
  }

  // ============================================================
  // NAVEGAÇÃO ENTRE DIAS
  // ============================================================

  void _diaAnterior() {
    setState(() {
      _diaSelecionado = DateTime(
        _diaSelecionado.year,
        _diaSelecionado.month,
        _diaSelecionado.day - 1,
      );
    });

    _carregarDoses();
  }

  void _diaSeguinte() {
    setState(() {
      _diaSelecionado = DateTime(
        _diaSelecionado.year,
        _diaSelecionado.month,
        _diaSelecionado.day + 1,
      );
    });

    _carregarDoses();
  }

  // ============================================================
  // DATAS
  // ============================================================

  String _formatarDataVisivel(DateTime data) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${data.day} de ${meses[data.month - 1]}';
  }

  String _tituloDia() {
    final hoje = DateTime.now();

    final hojeLimpo = DateTime.utc(hoje.year, hoje.month, hoje.day);

    final selecionado = DateTime.utc(
      _diaSelecionado.year,
      _diaSelecionado.month,
      _diaSelecionado.day,
    );

    final diferenca = selecionado.difference(hojeLimpo).inDays;

    if (diferenca == 0) {
      return 'Hoje';
    }

    if (diferenca == -1) {
      return 'Ontem';
    }

    if (diferenca == 1) {
      return 'Amanhã';
    }

    return 'Dia ${_diaSelecionado.day}';
  }

  // ============================================================
  // DESCRIÇÃO
  // ============================================================

  String _responsavel(Map<String, dynamic> r, DateTime dia) {
    final slot = SharedService.instance.slot(
      r['id'] as int,
      AgendaService.formatarData(dia),
      r['horario'].toString(),
    );
    if (slot?['administrado'] != 1) return '';
    final when = DateTime.tryParse(slot?['administrado_em']?.toString() ?? '')
        ?.toLocal();
    final hour = when == null
        ? 'horário desconhecido'
        : '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return '\nAdministrado por ${slot?['actorName']} às $hour';
  }

  String _descricaoMedicamento(Map<String, dynamic> medicamento) {
    final dose = medicamento['dose']?.toString().trim() ?? '';

    final unidade = medicamento['unidade']?.toString().trim() ?? '';

    final instrucoes = medicamento['instrucoes']?.toString().trim() ?? '';

    String descricao = dose;

    if (unidade.isNotEmpty) {
      descricao += ' $unidade';
    }

    if (instrucoes.isNotEmpty) {
      descricao += ' • $instrucoes';
    }

    return descricao;
  }

  Color _corDose(int index) {
    final cores = [
      AppColors.greenSoft,
      AppColors.pinkSoft,
      AppColors.beigeSoft,
      AppColors.blueSoft,
    ];

    return cores[index % cores.length];
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final totalDoses = _doses.length;

    final dosesAdministradas = _doses.where((dose) => dose.administrado).length;

    final progresso = totalDoses == 0 ? 0.0 : dosesAdministradas / totalDoses;

    final porcentagem = (progresso * 100).round();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      // ========================================================
      // MENU LATERAL
      // ========================================================
      drawer: Drawer(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drác ♡',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Controle de medicação',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Medicamentos'),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicamentosScreen(),
                    ),
                  );

                  _carregarDoses();
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.pets_outlined,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Dados do Drác'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DracScreen()),
                  );
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.medical_information_outlined,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Tratamento'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TratamentoScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // CONTEÚDO
      // ========================================================
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _carregarDoses,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DracHeader(
                  onMenuTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),

                Transform.translate(
                  offset: const Offset(0, -52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: DateSelectorCard(
                      titulo: _tituloDia(),
                      data: _formatarDataVisivel(_diaSelecionado),
                      onAnterior: _diaAnterior,
                      onProximo: _diaSeguinte,
                    ),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProgressCard(
                          dosesAdministradas: dosesAdministradas,
                          totalDoses: totalDoses,
                          progresso: progresso,
                          porcentagem: porcentagem,
                        ),

                        const SizedBox(height: 26),

                        Text(
                          _tituloDia() == 'Hoje'
                              ? 'Medicações de hoje'
                              : 'Medicações do dia',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 15),

                        if (_erro)
                          TextButton.icon(
                            onPressed: _carregarDoses,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Não foi possível carregar. Tentar novamente',
                            ),
                          )
                        else if (_carregando)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_doses.isEmpty)
                          _estadoSemMedicamentos()
                        else
                          ...List.generate(_doses.length, (index) {
                            final dose = _doses[index];

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == _doses.length - 1 ? 0 : 11,
                              ),
                              child: DoseCard(
                                horario: dose.horario,
                                nome: dose.nome,
                                descricao: dose.descricao,
                                cor: _corDose(index),
                                icon: Icons.medication_outlined,
                                administrado: dose.administrado,
                                onTap: () {
                                  _alternarDose(index);
                                },
                              ),
                            );
                          }),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _estadoSemMedicamentos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.medication_outlined,
            size: 38,
            color: AppColors.primaryDark,
          ),

          const SizedBox(height: 12),

          const Text(
            'Nenhuma medicação para este dia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Cadastre um medicamento ou confira o período do tratamento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicamentosScreen()),
              );

              _carregarDoses();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar medicamento'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODELO INTERNO DA DOSE
// ============================================================

class _DoseDoDia {
  final int medicamentoId;
  final String nome;
  final String horario;
  final String descricao;
  final bool administrado;

  const _DoseDoDia({
    required this.medicamentoId,
    required this.nome,
    required this.horario,
    required this.descricao,
    required this.administrado,
  });

  _DoseDoDia copyWith({bool? administrado}) {
    return _DoseDoDia(
      medicamentoId: medicamentoId,
      nome: nome,
      horario: horario,
      descricao: descricao,
      administrado: administrado ?? this.administrado,
    );
  }
}
