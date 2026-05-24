import 'package:flutter/material.dart';

import '../models/server.dart';

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
      return (background: const Color(0xFFDCFCE7), foreground: const Color(0xFF166534));
    case ServerStatus.dueSoon:
      return (background: const Color(0xFFFEF3C7), foreground: const Color(0xFF92400E));
    case ServerStatus.overdue:
      return (background: const Color(0xFFFEE2E2), foreground: const Color(0xFF991B1B));
    case ServerStatus.suspended:
      return (background: const Color(0xFFE0E7FF), foreground: const Color(0xFF3730A3));
    case ServerStatus.retired:
      return (background: const Color(0xFFE5E7EB), foreground: const Color(0xFF374151));
  }
}
