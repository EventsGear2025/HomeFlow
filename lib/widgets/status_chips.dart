import 'package:flutter/material.dart';
import '../models/supply_item.dart';
import '../utils/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.fontSize = 12,
  });

  factory StatusChip.fromSupplyStatus(SupplyStatus status) {
    switch (status) {
      case SupplyStatus.enough:
        return StatusChip(
          label: 'Enough',
          backgroundColor: AppColors.statusEnough,
          textColor: AppColors.statusEnoughText,
        );
      case SupplyStatus.runningLow:
        return StatusChip(
          label: 'Running Low',
          backgroundColor: AppColors.statusLow,
          textColor: AppColors.statusLowText,
        );
      case SupplyStatus.veryLow:
        return StatusChip(
          label: 'Very Low',
          backgroundColor: AppColors.statusVeryLow,
          textColor: AppColors.statusVeryLowText,
        );
      case SupplyStatus.finished:
        return StatusChip(
          label: 'Finished',
          backgroundColor: AppColors.statusFinished,
          textColor: AppColors.statusFinishedText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class UrgencyChip extends StatelessWidget {
  final String label;
  final bool isOrange;

  const UrgencyChip({super.key, required this.label, this.isOrange = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOrange
            ? AppColors.accentOrange.withValues(alpha: 0.12)
            : AppColors.accentYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOrange ? AppColors.accentOrange : AppColors.statusLowText,
        ),
      ),
    );
  }
}

class ReadinessChip extends StatelessWidget {
  final bool isReady;
  final String label;

  const ReadinessChip({super.key, required this.isReady, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.statusEnough
            : AppColors.statusVeryLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isReady
                ? AppColors.statusEnoughText
                : AppColors.statusVeryLowText,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isReady
                  ? AppColors.statusEnoughText
                  : AppColors.statusVeryLowText,
            ),
          ),
        ],
      ),
    );
  }
}
