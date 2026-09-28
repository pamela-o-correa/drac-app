import 'package:flutter/material.dart';

class DracHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const DracHeader({
    super.key,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foto do Drác
          Image.asset(
            'assets/images/drac_header.jpeg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
          ),

          // Sombra suave na imagem
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),

          // Botão de menu
          Positioned(
            top: 22,
            left: 22,
            child: _HeaderButton(
              icon: Icons.menu_rounded,
              onTap: onMenuTap,
            ),
          ),
          // Nome e subtítulo
          const Positioned(
            left: 28,
            bottom: 105,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drác ♡',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 39,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  'Controle de medicação',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 30,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}