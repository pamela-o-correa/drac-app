import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';

class TratamentoScreen extends StatefulWidget {
  const TratamentoScreen({super.key});

  @override
  State<TratamentoScreen> createState() => _TratamentoScreenState();
}

class _TratamentoScreenState extends State<TratamentoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _veterinarioController = TextEditingController();
  final _dataInicioController = TextEditingController();
  final _dataFimController = TextEditingController();
  final _orientacoesController = TextEditingController();
  final _observacoesController = TextEditingController();

  int? _tratamentoId;

  bool _ativo = true;
  int _expectedVersion = SharedService.instance.revision;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();

    _carregarTratamento();
  }

  Future<void> _carregarTratamento() async {
    final tratamentos = await DatabaseHelper.instance.buscarTratamentos();

    if (!mounted) {
      return;
    }

    if (tratamentos.isNotEmpty) {
      final tratamento = tratamentos.first;

      _tratamentoId = tratamento['id'];

      _tituloController.text = tratamento['titulo']?.toString() ?? '';

      _veterinarioController.text = tratamento['veterinario']?.toString() ?? '';

      _dataInicioController.text = tratamento['data_inicio']?.toString() ?? '';

      _dataFimController.text = tratamento['data_fim']?.toString() ?? '';

      _orientacoesController.text = tratamento['orientacoes']?.toString() ?? '';

      _observacoesController.text = tratamento['observacoes']?.toString() ?? '';

      _ativo = tratamento['ativo'] == 1;
    }

    setState(() {
      _carregando = false;
    });
  }

  Future<void> _selecionarData(TextEditingController controller) async {
    final agora = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (data == null) {
      return;
    }

    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    controller.text = '$dia/$mes/${data.year}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      if (_tratamentoId == null) {
        final id = await DatabaseHelper.instance.adicionarTratamento(
          titulo: _tituloController.text.trim(),
          ativo: _ativo,
          veterinario: _veterinarioController.text.trim(),
          dataInicio: _dataInicioController.text.trim(),
          dataFim: _dataFimController.text.trim(),
          orientacoes: _orientacoesController.text.trim(),
          observacoes: _observacoesController.text.trim(),
        );

        _tratamentoId = id;
      } else {
        await DatabaseHelper.instance.atualizarTratamento(_tratamentoId!, {
          'titulo': _tituloController.text.trim(),
          'veterinario': _veterinarioController.text.trim(),
          'data_inicio': _dataInicioController.text.trim(),
          'data_fim': _dataFimController.text.trim(),
          'orientacoes': _orientacoesController.text.trim(),
          'observacoes': _observacoesController.text.trim(),
          'ativo': _ativo ? 1 : 0,
        }, expectedVersion: _expectedVersion);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tratamento salvo.')));
      _expectedVersion = SharedService.instance.revision;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _veterinarioController.dispose();
    _dataInicioController.dispose();
    _dataFimController.dispose();
    _orientacoesController.dispose();
    _observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: const Text('Tratamento')),

      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campo(
                        controller: _tituloController,
                        label: 'Título do tratamento',
                        hint: 'Ex.: Tratamento atual',
                        obrigatorio: true,
                      ),

                      const SizedBox(height: 16),

                      _campo(
                        controller: _veterinarioController,
                        label: 'Veterinário',
                        hint: 'Nome do veterinário',
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Período',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _campoData(
                              controller: _dataInicioController,
                              label: 'Início',
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _campoData(
                              controller: _dataFimController,
                              label: 'Fim',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      _campo(
                        controller: _orientacoesController,
                        label: 'Orientações',
                        hint: 'Ex.: Administrar junto com alimento',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 16),

                      _campo(
                        controller: _observacoesController,
                        label: 'Observações',
                        hint: 'Outras informações importantes',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 22),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Tratamento ativo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Desative quando o tratamento terminar.',
                          ),
                          value: _ativo,
                          onChanged: (valor) {
                            setState(() {
                              _ativo = valor;
                            });
                          },
                        ),
                      ),

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
                            : const Text('Salvar tratamento'),
                      ),
                    ],
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
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
      validator: obrigatorio
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
      controller: controller,
      readOnly: true,
      onTap: () => _selecionarData(controller),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd/mm/aaaa',
        suffixIcon: const Icon(Icons.calendar_month_outlined),
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
