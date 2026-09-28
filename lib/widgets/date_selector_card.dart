import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class DateSelectorCard extends StatelessWidget {
  final String titulo;
  final String data;
  final VoidCallback? onAnterior;
  final VoidCallback? onProximo;

  const DateSelectorCard({
    super.key,
    required this.titulo,
    required this.data,
    this.onAnterior,
    this.onProximo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onProximo,
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}