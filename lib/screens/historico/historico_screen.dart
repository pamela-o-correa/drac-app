import 'auditoria_screen.dart';

import 'dart:async';

import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/agenda_service.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool _carregando = true;
  bool _erro = false;
  int _consulta = 0;

  List<_HistoricoDia> _historico = [];

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
      if (mounted) _carregarHistorico();
    });

    _carregarHistorico();
  }

  // ============================================================
  // CARREGAMENTO DO HISTÓRICO
  // ============================================================

  Future<void> _carregarHistorico() async {
    if (!mounted) return;
    final consulta = ++_consulta;
    final periodo = _mesSelecionado;
    setState(() {
      _carregando = true;
      _erro = false;
      _historico = [];
    });
    try {
      final ultimo = DateTime(periodo.year, periodo.month + 1, 0);
      final agenda = await AgendaService.carregar(periodo, ultimo);
      final resultado = <_HistoricoDia>[];
      for (var dia = 1; dia <= ultimo.day; dia++) {
        final data = DateTime(periodo.year, periodo.month, dia);
        final doses = agenda.dosesDoDia(data);
        final administradas = doses
            .where((r) => r['administrado'] == true)
            .length;
        if (doses.isNotEmpty) {
          resultado.add(
            _HistoricoDia(
              data: data,
              totalDoses: doses.length,
              dosesAdministradas: administradas,
            ),
          );
        }
      }
      resultado.sort((a, b) => b.data.compareTo(a.data));
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _historico = resultado;
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

    _carregarHistorico();
  }

  void _mesSeguinte() {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + 1,
      );
    });

    _carregarHistorico();
  }

  // ============================================================
  // CONTROLE DE PERÍODO DOS MEDICAMENTOS
  // ============================================================

  String _formatarDia(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes';
  }

  String _nomeDiaSemana(DateTime data) {
    const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return dias[data.weekday - 1];
  }

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

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarHistorico,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Histórico de ações e responsáveis'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuditoriaScreen()),
                ),
              ),
              const Text(
                'Histórico',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Veja como foram as medicações do Drác em cada dia.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              // Seletor do mês
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _mesAnterior,
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    Expanded(
                      child: Text(
                        '${_nomeMes(_mesSelecionado.month)} '
                        '${_mesSelecionado.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: _mesSeguinte,
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_erro)
                TextButton.icon(
                  onPressed: _carregarHistorico,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Não foi possível carregar. Tentar novamente',
                  ),
                )
              else if (_carregando)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_historico.isEmpty)
                _estadoVazio()
              else
                ...List.generate(_historico.length, (index) {
                  final item = _historico[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _historico.length - 1 ? 0 : 12,
                    ),
                    child: _HistoricoCard(
                      data: _formatarDia(item.data),
                      diaSemana: _nomeDiaSemana(item.data),
                      dosesAdministradas: item.dosesAdministradas,
                      totalDoses: item.totalDoses,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, size: 40, color: AppColors.primaryDark),

          SizedBox(height: 14),

          Text(
            'Nenhum histórico neste mês',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Os dias com medicações programadas aparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DO HISTÓRICO
// ============================================================

class _HistoricoCard extends StatelessWidget {
  final String data;
  final String diaSemana;
  final int dosesAdministradas;
  final int totalDoses;

  const _HistoricoCard({
    required this.data,
    required this.diaSemana,
    required this.dosesAdministradas,
    required this.totalDoses,
  });

  @override
  Widget build(BuildContext context) {
    final progresso = totalDoses == 0 ? 0.0 : dosesAdministradas / totalDoses;

    final porcentagem = (progresso * 100).round();

    final completo = dosesAdministradas == totalDoses;

    final nenhum = dosesAdministradas == 0;

    final Color corProgresso;

    if (completo) {
      corProgresso = AppColors.success;
    } else if (nenhum) {
      corProgresso = AppColors.pending;
    } else {
      corProgresso = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '$data ($diaSemana)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        '$dosesAdministradas de $totalDoses doses',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$porcentagem%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(width: 4),

              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              color: corProgresso,
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODELO INTERNO
// ============================================================

class _HistoricoDia {
  final DateTime data;
  final int totalDoses;
  final int dosesAdministradas;

  const _HistoricoDia({
    required this.data,
    required this.totalDoses,
    required this.dosesAdministradas,
  });
}
