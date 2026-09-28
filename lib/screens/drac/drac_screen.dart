import '../../services/shared_service.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';

class DracScreen extends StatefulWidget {
  const DracScreen({super.key});

  @override
  State<DracScreen> createState() => _DracScreenState();
}

class _DracScreenState extends State<DracScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _nascimentoController = TextEditingController();
  final _observacoesController = TextEditingController();

  int? _dracId;

  int _expectedVersion = SharedService.instance.revision;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();

    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final dados = await DatabaseHelper.instance.buscarDrac();

    if (!mounted) {
      return;
    }

    if (dados != null) {
      _dracId = dados['id'];

      _nomeController.text = dados['nome']?.toString() ?? '';

      _pesoController.text = dados['peso']?.toString() ?? '';

      _nascimentoController.text = dados['nascimento']?.toString() ?? '';

      _observacoesController.text = dados['observacoes']?.toString() ?? '';
    } else {
      _nomeController.text = 'Drác';
    }

    setState(() {
      _carregando = false;
    });
  }

  Future<void> _selecionarNascimento() async {
    final agora = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(agora.year - 1, agora.month, agora.day),
      firstDate: DateTime(2000),
      lastDate: agora,
    );

    if (data == null) {
      return;
    }

    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    _nascimentoController.text = '$dia/$mes/${data.year}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pesoTexto = _pesoController.text.trim().replaceAll(',', '.');

    final peso = pesoTexto.isEmpty ? null : double.tryParse(pesoTexto);

    if (pesoTexto.isNotEmpty && peso == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um peso válido.')));

      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      if (_dracId == null) {
        final id = await DatabaseHelper.instance.salvarDrac(
          nome: _nomeController.text.trim(),
          peso: peso,
          nascimento: _nascimentoController.text.trim(),
          observacoes: _observacoesController.text.trim(),
        );

        _dracId = id;
      } else {
        await DatabaseHelper.instance.atualizarDrac(
          id: _dracId!,
          expectedVersion: _expectedVersion,
          nome: _nomeController.text.trim(),
          peso: peso,
          nascimento: _nascimentoController.text.trim(),
          observacoes: _observacoesController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dados do Drác salvos.')));
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
    _nomeController.dispose();
    _pesoController.dispose();
    _nascimentoController.dispose();
    _observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: const Text('Dados do Drác')),

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
                      Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 3,
                            ),
                            image: const DecorationImage(
                              image: AssetImage(
                                'assets/images/drac_header.jpeg',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      _campo(
                        controller: _nomeController,
                        label: 'Nome',
                        hint: 'Ex.: Drác',
                        obrigatorio: true,
                      ),

                      const SizedBox(height: 16),

                      _campo(
                        controller: _pesoController,
                        label: 'Peso',
                        hint: 'Ex.: 4,8 kg',
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nascimentoController,
                        readOnly: true,
                        onTap: _selecionarNascimento,
                        decoration: InputDecoration(
                          labelText: 'Data de nascimento',
                          hintText: 'dd/mm/aaaa',
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _campo(
                        controller: _observacoesController,
                        label: 'Observações',
                        hint: 'Informações importantes sobre o Drác',
                        maxLines: 5,
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
                            : const Text('Salvar dados'),
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
    TextInputType? teclado,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: teclado,
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
}
