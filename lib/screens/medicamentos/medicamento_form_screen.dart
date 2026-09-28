import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/despertador_service.dart';
import '../../services/agenda_service.dart';

class MedicamentoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? medicamento;

  const MedicamentoFormScreen({super.key, this.medicamento});

  @override
  State<MedicamentoFormScreen> createState() => _MedicamentoFormScreenState();
}

class _MedicamentoFormScreenState extends State<MedicamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _doseController = TextEditingController();
  final _unidadeController = TextEditingController();
  final _instrucoesController = TextEditingController();
  final _dataInicioController = TextEditingController();
  final _dataFimController = TextEditingController();
  final _duracaoController = TextEditingController();

  final List<TimeOfDay> _horarios = [];
  TipoPeriodo _tipoPeriodo = TipoPeriodo.dataFinal;

  late final int _expectedVersion;
  bool _salvando = false;
  bool _carregando = false;
  bool _erroAoCarregar = false;

  bool get editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();
    _expectedVersion =
        (widget.medicamento?['_shared_version'] as int?) ??
        SharedService.instance.revision;
    _dataInicioController.addListener(_atualizarPeriodo);
    _duracaoController.addListener(_atualizarPeriodo);
    if (editando) {
      _carregando = true;
      _carregarMedicamento();
    }
  }

  void _atualizarPeriodo() {
    if (mounted) setState(() {});
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _carregarMedicamento() async {
    try {
      final medicamento = widget.medicamento!;
      _nomeController.text = medicamento['nome']?.toString() ?? '';
      _doseController.text = medicamento['dose']?.toString() ?? '';
      _unidadeController.text = medicamento['unidade']?.toString() ?? '';
      _instrucoesController.text = medicamento['instrucoes']?.toString() ?? '';
      _dataInicioController.text = medicamento['data_inicio']?.toString() ?? '';
      _dataFimController.text = medicamento['data_fim']?.toString() ?? '';
      _tipoPeriodo = _dataFimController.text.trim().isEmpty
          ? TipoPeriodo.continuo
          : TipoPeriodo.dataFinal;

      final registros = await DatabaseHelper.instance.buscarHorarios(
        medicamento['id'],
      );
      if (!mounted) return;
      final horarios = <TimeOfDay>[];
      for (final registro in registros) {
        final partes = (registro['horario']?.toString() ?? '').split(':');
        if (partes.length != 2) throw const FormatException('Horário inválido');
        final hora = int.tryParse(partes[0]);
        final minuto = int.tryParse(partes[1]);
        if (hora == null ||
            minuto == null ||
            hora < 0 ||
            hora > 23 ||
            minuto < 0 ||
            minuto > 59) {
          throw const FormatException('Horário inválido');
        }
        if (!horarios.any((h) => h.hour == hora && h.minute == minuto)) {
          horarios.add(TimeOfDay(hour: hora, minute: minuto));
        }
      }
      horarios.sort(_compararHorarios);
      _horarios
        ..clear()
        ..addAll(horarios);
      _erroAoCarregar = false;
    } catch (_) {
      if (mounted) _erroAoCarregar = true;
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int _compararHorarios(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  Future<void> _adicionarHorario() async {
    if (_salvando || _carregando) return;
    final horario = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted || horario == null || _salvando) return;
    if (_horarios.any(
      (h) => h.hour == horario.hour && h.minute == horario.minute,
    )) {
      _mostrarMensagem('Este horário já foi adicionado.');
      return;
    }
    setState(() {
      _horarios.add(horario);
      _horarios.sort(_compararHorarios);
    });
  }

  String _formatarHorario(TimeOfDay horario) =>
      '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';

  Future<void> _selecionarData(TextEditingController controller) async {
    if (_salvando || _carregando) return;
    final inicial =
        _converterData(controller.text) ??
        (controller == _dataFimController
            ? _converterData(_dataInicioController.text)
            : null) ??
        DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(inicial.year < 2020 ? inicial.year : 2020),
      lastDate: DateTime(inicial.year > 2040 ? inicial.year : 2040, 12, 31),
    );
    if (!mounted || data == null || _salvando) return;
    controller.text = _formatarData(data);
  }

  DateTime? _converterData(String texto) => AgendaService.converterData(texto);
  String _formatarData(DateTime data) => AgendaService.formatarData(data);

  String? _calcularDataFim() {
    final inicio = _converterData(_dataInicioController.text);
    final dias = int.tryParse(_duracaoController.text.trim());
    if (inicio == null || dias == null || dias <= 0) return null;
    // UTC evita que o horário de verão altere a contagem de dias.
    final inicioUtc = DateTime.utc(inicio.year, inicio.month, inicio.day);
    if (dias > DateTime.utc(9999, 12, 31).difference(inicioUtc).inDays + 1) {
      return null;
    }
    // O início é o dia 1.
    return _formatarData(inicioUtc.add(Duration(days: dias - 1)));
  }

  Future<void> _salvar() async {
    if (_salvando || _carregando || _erroAoCarregar) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_horarios.isEmpty) {
      _mostrarMensagem('Adicione pelo menos um horário.');
      return;
    }
    final inicio = _converterData(_dataInicioController.text);
    if (inicio == null) {
      _mostrarMensagem('Informe uma data de início válida.');
      return;
    }
    String? dataFim;
    if (_tipoPeriodo == TipoPeriodo.quantidadeDias) {
      dataFim = _calcularDataFim();
      if (dataFim == null) {
        _mostrarMensagem('Informe uma quantidade de dias válida.');
        return;
      }
    } else if (_tipoPeriodo == TipoPeriodo.dataFinal) {
      final fim = _converterData(_dataFimController.text);
      if (fim == null || fim.isBefore(inicio)) {
        _mostrarMensagem(
          'Informe uma data final igual ou posterior ao início.',
        );
        return;
      }
      dataFim = _formatarData(fim);
    }
    final dados = <String, Object?>{
      'nome': _nomeController.text.trim(),
      'dose': _doseController.text.trim(),
      'unidade': _unidadeController.text.trim(),
      'instrucoes': _instrucoesController.text.trim(),
      'data_inicio': _formatarData(inicio),
      'data_fim': dataFim,
    };
    final horarios = _horarios.map(_formatarHorario).toList();
    setState(() => _salvando = true);
    try {
      await DatabaseHelper.instance.salvarMedicamentoCompleto(
        id: editando ? widget.medicamento!['id'] as int : null,
        dados: dados,
        horarios: horarios,
        expectedVersion: _expectedVersion,
      );
      try {
        await DespertadorService.sincronizar();
      } catch (_) {
        _mostrarMensagem(
          'Medicamento salvo, mas o despertador não foi atualizado. Confira as configurações.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarMensagem('Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _dataInicioController.removeListener(_atualizarPeriodo);
    _duracaoController.removeListener(_atualizarPeriodo);
    _nomeController.dispose();
    _doseController.dispose();
    _unidadeController.dispose();
    _instrucoesController.dispose();
    _dataInicioController.dispose();
    _dataFimController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_salvando,
      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
          title: Text(editando ? 'Editar medicamento' : 'Novo medicamento'),
        ),

        body: SafeArea(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erroAoCarregar
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível carregar o medicamento.'),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _carregando = true;
                            _erroAoCarregar = false;
                          });
                          _carregarMedicamento();
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : AbsorbPointer(
                  absorbing: _salvando,
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campo(
                            controller: _nomeController,
                            label: 'Nome do medicamento',
                            hint: 'Ex.: SAMe 60 mg',
                            obrigatorio: true,
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _campo(
                                  controller: _doseController,
                                  label: 'Dose',
                                  hint: 'Ex.: 1',
                                  obrigatorio: true,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: _campo(
                                  controller: _unidadeController,
                                  label: 'Unidade',
                                  hint: 'Ex.: mL',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _campo(
                            controller: _instrucoesController,
                            label: 'Como administrar',
                            hint: 'Ex.: Em jejum, pela manhã',
                            maxLines: 3,
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            'Horários',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Você pode adicionar mais de um horário.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._horarios.map((horario) {
                                return InputChip(
                                  label: Text(_formatarHorario(horario)),
                                  onDeleted: () {
                                    setState(() {
                                      _horarios.remove(horario);
                                    });
                                  },
                                );
                              }),

                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 19),
                                label: const Text('Adicionar horário'),
                                onPressed: _adicionarHorario,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Período',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _campoData(
                            controller: _dataInicioController,
                            label: 'Início',
                          ),

                          const SizedBox(height: 16),

                          RadioGroup<TipoPeriodo>(
                            groupValue: _tipoPeriodo,
                            onChanged: (valor) {
                              if (valor != null) {
                                setState(() => _tipoPeriodo = valor);
                              }
                            },
                            child: const Column(
                              children: [
                                RadioListTile<TipoPeriodo>(
                                  value: TipoPeriodo.dataFinal,
                                  title: Text('Informar data final'),
                                ),
                                RadioListTile<TipoPeriodo>(
                                  value: TipoPeriodo.quantidadeDias,
                                  title: Text('Informar quantidade de dias'),
                                ),
                                RadioListTile<TipoPeriodo>(
                                  value: TipoPeriodo.continuo,
                                  title: Text('Uso contínuo'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (_tipoPeriodo == TipoPeriodo.dataFinal)
                            _campoData(
                              controller: _dataFimController,
                              label: 'Fim',
                            ),

                          if (_tipoPeriodo == TipoPeriodo.quantidadeDias) ...[
                            _campo(
                              controller: _duracaoController,
                              label: 'Duração',
                              hint: 'Ex.: 10',
                              teclado: TextInputType.number,
                            ),

                            const SizedBox(height: 10),

                            Builder(
                              builder: (context) {
                                final dataFim = _calcularDataFim();

                                if (dataFim == null) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Término previsto: $dataFim',
                                    style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 30),

                          FilledButton(
                            onPressed: _salvando ? null : _salvar,
                            child: _salvando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    editando
                                        ? 'Salvar alterações'
                                        : 'Adicionar medicamento',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obrigatorio = false,
    int maxLines = 1,
    TextInputType? teclado,
  }) {
    return TextFormField(
      key: ObjectKey(controller),
      controller: controller,
      keyboardType: teclado,
      maxLines: maxLines,
      decoration: InputDecoration(
        errorMaxLines: 3,
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      validator: controller == _duracaoController
          ? (valor) {
              final dias = int.tryParse(valor?.trim() ?? '');
              if (dias == null || dias <= 0) {
                return 'Informe um número inteiro maior que zero';
              }
              if (_converterData(_dataInicioController.text) != null &&
                  _calcularDataFim() == null) {
                return 'Duração muito longa';
              }
              return null;
            }
          : obrigatorio
          ? (valor) {
              if (valor == null || valor.trim().isEmpty) {
                return 'Campo obrigatório';
              }

              return null;
            }
          : null,
    );
  }

  Widget _campoData({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: ObjectKey(controller),
      controller: controller,
      readOnly: true,
      validator: (valor) {
        final data = _converterData(valor ?? '');
        if (data == null) return 'Informe uma data válida';
        final inicio = _converterData(_dataInicioController.text);
        if (controller == _dataFimController &&
            inicio != null &&
            data.isBefore(inicio)) {
          return 'A data final não pode ser anterior ao início';
        }
        return null;
      },
      onTap: () => _selecionarData(controller),
      decoration: InputDecoration(
        errorMaxLines: 3,
        labelText: label,
        hintText: 'dd/mm/aaaa',
        suffixIcon: const Icon(Icons.calendar_month),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

enum TipoPeriodo { dataFinal, quantidadeDias, continuo }
