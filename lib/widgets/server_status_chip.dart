import 'package:flutter/material.dart';

import '../models/server.dart';
import '../theme/app_theme.dart';

class ServerStatusChip extends StatelessWidget {
  const ServerStatusChip({super.key, required this.status});

  final ServerStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

({Color background, Color foreground}) _colorsForStatus(ServerStatus status) {
  switch (status) {
    case ServerStatus.active:
      return (background: AppColors.successSoft, foreground: AppColors.success);
    case ServerStatus.dueSoon:
      return (background: AppColors.warningSoft, foreground: AppColors.warning);
    case ServerStatus.overdue:
      return (background: AppColors.dangerSoft, foreground: AppColors.danger);
    case ServerStatus.suspended:
      return (background: AppColors.violetSoft, foreground: AppColors.violet);
    case ServerStatus.retired:
      return (background: AppColors.neutralSoft, foreground: AppColors.neutral);
  }
}
