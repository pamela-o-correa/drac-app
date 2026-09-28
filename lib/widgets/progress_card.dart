import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class ProgressCard extends StatelessWidget {
  final int dosesAdministradas;
  final int totalDoses;
  final double progresso;
  final int porcentagem;

  const ProgressCard({
    super.key,
    required this.dosesAdministradas,
    required this.totalDoses,
    required this.progresso,
    required this.porcentagem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dosesAdministradas de $totalDoses doses',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$porcentagem%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(10),
            ),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 9,
            ),
          ),
        ],
      ),
    );
  }
}