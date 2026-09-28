import 'dart:async';

import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/agenda_service.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool _carregando = true;
  bool _erro = false;
  int _consulta = 0;

  Map<int, _StatusDia> _statusDosDias = {};

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
      if (mounted) _carregarCalendario();
    });

    _carregarCalendario();
  }

  // ============================================================
  // CARREGAMENTO
  // ============================================================

  Future<void> _carregarCalendario() async {
    if (!mounted) return;
    final consulta = ++_consulta;
    final periodo = _mesSelecionado;
    setState(() {
      _carregando = true;
      _erro = false;
      _statusDosDias = {};
    });
    try {
      final ultimo = DateTime(periodo.year, periodo.month + 1, 0);
      final agenda = await AgendaService.carregar(periodo, ultimo);
      final resultado = <int, _StatusDia>{};
      for (var dia = 1; dia <= ultimo.day; dia++) {
        final data = DateTime(periodo.year, periodo.month, dia);
        final doses = agenda.dosesDoDia(data);
        final administradas = doses
            .where((r) => r['administrado'] == true)
            .length;
        resultado[dia] = doses.isEmpty
            ? _StatusDia.semMedicacao
            : administradas == doses.length
            ? _StatusDia.completo
            : administradas == 0
            ? _StatusDia.pendente
            : _StatusDia.parcial;
      }
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _statusDosDias = resultado;
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
  // NAVEGAÇÃO ENTRE MESES
  // ============================================================

  void _mesAnterior() {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month - 1,
      );
    });

    _carregarCalendario();
  }

  void _mesSeguinte() {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + 1,
      );
    });

    _carregarCalendario();
  }

  // ============================================================
  // DATAS
  // ============================================================

  String _nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return meses[mes - 1];
  }

  bool _ehHoje(int dia) {
    final hoje = DateTime.now();

    return hoje.year == _mesSelecionado.year &&
        hoje.month == _mesSelecionado.month &&
        hoje.day == dia;
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarCalendario,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              const Text(
                'Calendário',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Acompanhe as medicações do Drác por dia.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _mesAnterior,
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            '${_nomeMes(_mesSelecionado.month)} '
                            '${_mesSelecionado.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: _mesSeguinte,
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Row(
                      children: [
                        _DiaSemana('Dom'),
                        _DiaSemana('Seg'),
                        _DiaSemana('Ter'),
                        _DiaSemana('Qua'),
                        _DiaSemana('Qui'),
                        _DiaSemana('Sex'),
                        _DiaSemana('Sáb'),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (_erro)
                      TextButton.icon(
                        onPressed: _carregarCalendario,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Não foi possível carregar. Tentar novamente',
                        ),
                      )
                    else if (_carregando)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      )
                    else
                      _CalendarioGrid(
                        mes: _mesSelecionado,
                        statusDosDias: _statusDosDias,
                        ehHoje: _ehHoje,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Legenda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    _LegendaItem(
                      cor: AppColors.success,
                      texto: 'Todas as doses administradas',
                    ),

                    SizedBox(height: 14),

                    _LegendaItem(
                      cor: AppColors.primary,
                      texto: 'Algumas doses administradas',
                    ),

                    SizedBox(height: 14),

                    _LegendaItem(
                      cor: AppColors.pending,
                      texto: 'Dose pendente',
                    ),

                    SizedBox(height: 14),

                    _LegendaItem(
                      cor: AppColors.disabled,
                      texto: 'Sem medicação',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GRID
// ============================================================

class _CalendarioGrid extends StatelessWidget {
  final DateTime mes;
  final Map<int, _StatusDia> statusDosDias;
  final bool Function(int dia) ehHoje;

  const _CalendarioGrid({
    required this.mes,
    required this.statusDosDias,
    required this.ehHoje,
  });

  @override
  Widget build(BuildContext context) {
    final primeiroDia = DateTime(mes.year, mes.month, 1);

    final ultimoDia = DateTime(mes.year, mes.month + 1, 0);

    final quantidadeDias = ultimoDia.day;

    final espacosAntes = primeiroDia.weekday % 7;

    final totalCelulas = espacosAntes + quantidadeDias;

    final linhas = (totalCelulas / 7).ceil();

    return Column(
      children: List.generate(linhas, (linha) {
        return Row(
          children: List.generate(7, (coluna) {
            final indice = (linha * 7) + coluna;

            final dia = indice - espacosAntes + 1;

            if (dia < 1 || dia > quantidadeDias) {
              return const Expanded(child: SizedBox(height: 54));
            }

            return Expanded(
              child: _CelulaDia(
                dia: dia,
                status: statusDosDias[dia] ?? _StatusDia.semMedicacao,
                selecionado: ehHoje(dia),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ============================================================
// CÉLULA DO DIA
// ============================================================

class _CelulaDia extends StatelessWidget {
  final int dia;
  final _StatusDia status;
  final bool selecionado;

  const _CelulaDia({
    required this.dia,
    required this.status,
    required this.selecionado,
  });

  @override
  Widget build(BuildContext context) {
    final corStatus = _corDoStatus(status);

    return SizedBox(
      height: 54,
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selecionado ? AppColors.primaryDark : Colors.transparent,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$dia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                  color: selecionado ? Colors.white : AppColors.textPrimary,
                ),
              ),

              Positioned(
                bottom: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selecionado ? Colors.white : corStatus,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corDoStatus(_StatusDia status) {
    switch (status) {
      case _StatusDia.completo:
        return AppColors.success;

      case _StatusDia.parcial:
        return AppColors.primary;

      case _StatusDia.pendente:
        return AppColors.pending;

      case _StatusDia.semMedicacao:
        return AppColors.disabled;
    }
  }
}

// ============================================================
// DIA DA SEMANA
// ============================================================

class _DiaSemana extends StatelessWidget {
  final String texto;

  const _DiaSemana(this.texto);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ============================================================
// LEGENDA
// ============================================================

class _LegendaItem extends StatelessWidget {
  final Color cor;
  final String texto;

  const _LegendaItem({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STATUS
// ============================================================

enum _StatusDia { completo, parcial, pendente, semMedicacao }
