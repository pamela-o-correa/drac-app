import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class DoseCard extends StatelessWidget {
  final String horario;
  final String nome;
  final String descricao;
  final Color cor;
  final IconData icon;
  final bool administrado;
  final VoidCallback onTap;

  const DoseCard({
    super.key,
    required this.horario,
    required this.nome,
    required this.descricao,
    required this.cor,
    required this.icon,
    required this.administrado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 55,
              child: Text(
                horario,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryDark,
                size: 23,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    descricao,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: administrado
                    ? AppColors.success
                    : Colors.transparent,
                border: Border.all(
                  color: administrado
                      ? AppColors.success
                      : AppColors.disabled,
                  width: 2,
                ),
              ),
              child: administrado
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 19,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}