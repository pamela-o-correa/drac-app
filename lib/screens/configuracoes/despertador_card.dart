import 'package:flutter/material.dart';

import '../../services/despertador_service.dart';

class DespertadorCard extends StatefulWidget {
  const DespertadorCard({super.key});
  @override
  State<DespertadorCard> createState() => _DespertadorCardState();
}

class _DespertadorCardState extends State<DespertadorCard>
    with WidgetsBindingObserver {
  bool _ativo = false, _permitido = false, _ocupado = true;
  String? _erro;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _carregar();
  }

  Future<void> _carregar() async {
    try {
      final estado = await DespertadorService.status();
      if (mounted) {
        setState(() {
          _ativo = estado['ativo'] == true;
          _permitido = estado['permitido'] == true;
          _erro = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível consultar o despertador.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao();
      await _carregar();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível concluir. Confira as permissões e tente novamente.';
          _ocupado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponivel = DespertadorService.disponivel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.alarm),
              title: const Text('Despertador das doses'),
              subtitle: Text(
                !disponivel
                    ? 'Disponível no Android.'
                    : _ativo && !_permitido
                    ? 'Pausado: autorize notificações e alarmes.'
                    : 'Avisa 10 minutos antes e toca no horário de cada medicamento.',
              ),
              value: _ativo,
              onChanged: !disponivel || _ocupado
                  ? null
                  : (valor) => _executar(() async {
                      if (valor && !_permitido) {
                        await DespertadorService.permissoes();
                        return;
                      }
                      await DespertadorService.sincronizar(ativo: valor);
                    }),
            ),
            if (disponivel && !_permitido)
              TextButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _executar(DespertadorService.permissoes),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Autorizar despertador'),
              ),
            if (disponivel)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _ocupado || !_permitido
                        ? null
                        : () => _executar(DespertadorService.testar),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Testar som'),
                  ),
                  TextButton(
                    onPressed: _ocupado
                        ? null
                        : () => _executar(DespertadorService.parar),
                    child: const Text('Parar som'),
                  ),
                ],
              ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Use o volume de alarme do celular. Parar o som não marca a dose como administrada.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_erro != null)
              Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
