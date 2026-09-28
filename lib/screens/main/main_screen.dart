import 'dart:async';

import '../../services/shared_service.dart';
import '../../widgets/shared_status.dart';

import 'package:flutter/material.dart';

import '../../widgets/app_bottom_navigation.dart';
import '../../services/despertador_service.dart';
import '../calendario/calendario_screen.dart';
import '../configuracoes/configuracoes_screen.dart';
import '../historico/historico_screen.dart';
import '../home/home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  StreamSubscription<String>? _messages;
  @override
  void initState() {
    super.initState();
    _messages = SharedService.instance.messages.stream.listen((text) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    });
    WidgetsBinding.instance.addObserver(this);
    DespertadorService.channel.setMethodCallHandler((call) async {
      if (call.method == 'doseRegistrada' && mounted) {
        setState(() => _revisao++);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
  }

  @override
  void dispose() {
    _messages?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    DespertadorService.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _revisao++);
      _sincronizar();
    }
  }

  Future<void> _sincronizar() async {
    try {
      await DespertadorService.sincronizar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível atualizar o despertador. Confira as configurações.',
            ),
          ),
        );
      }
    }
  }

  int _selectedIndex = 0;
  int _revisao = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CalendarioScreen(),
    HistoricoScreen(),
    ConfiguracoesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SharedStatus(),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_revisao),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),

      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
