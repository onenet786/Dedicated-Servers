import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/server.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.store});

  final ServerStore store;

  @override
  Widget build(BuildContext context) {
    final roots = store.rootServers;
    final vms = store.servers.where((server) => server.isVirtualMachine).toList();
    final dueServers = roots.where((server) => server.daysUntilRenewal <= 30).toList()
      ..sort((a, b) => a.renewalDate.compareTo(b.renewalDate));
    final totalCpu = vms.fold<int>(0, (total, server) => total + (server.vmCpuCores ?? 0));
    final totalRam = vms.fold<double>(0, (total, server) => total + (server.vmMemoryGb ?? 0));
    final totalDisk = vms.fold<double>(0, (total, server) => total + (server.vmDiskGb ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F2FE), Color(0xFFF5F3FF), Color(0xFFFFFBEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _ReportHero(
                dedicatedCount: roots.length,
                vmCount: vms.length,
                monthlySpend: store.monthlySpend,
                dueCount: dueServers.length,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Dedicated Servers Report',
                icon: Icons.dns_rounded,
                color: AppColors.info,
                children: [
                  _MetricGrid(
                    metrics: [
                      _ReportMetric('Total', '${roots.length}', Icons.storage_outlined),
                      _ReportMetric('Active', '${_countStatus(roots, ServerStatus.active)}', Icons.check_circle_outline),
                      _ReportMetric('Due / Overdue', '${roots.where((server) => server.daysUntilRenewal <= 7).length}', Icons.event_busy_outlined),
                      _ReportMetric('Monthly', 'PKR ${store.monthlySpend.toStringAsFixed(0)}', Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._statusRows(roots),
                ],
              ),
              _SectionCard(
                title: 'Virtual Machines Report',
                icon: Icons.developer_board_outlined,
                color: AppColors.violet,
                children: [
                  _MetricGrid(
                    metrics: [
                      _ReportMetric('VMs', '${vms.length}', Icons.memory_outlined),
                      _ReportMetric('vCPU', '$totalCpu', Icons.speed_outlined),
                      _ReportMetric('RAM', '${totalRam.toStringAsFixed(1)} GB', Icons.sd_card_outlined),
                      _ReportMetric('Disk', '${totalDisk.toStringAsFixed(1)} GB', Icons.storage_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._topRows(_groupBy(vms, (server) => server.operatingSystem), vms.length, emptyText: 'No VM operating systems recorded.'),
                ],
              ),
              _SectionCard(
                title: 'Renewal Due Report',
                icon: Icons.event_available_outlined,
                color: AppColors.warning,
                children: [
                  _MetricGrid(
                    metrics: [
                      _ReportMetric('Overdue', '${roots.where((server) => server.daysUntilRenewal < 0).length}', Icons.warning_amber_outlined),
                      _ReportMetric('7 Days', '${roots.where((server) => server.daysUntilRenewal >= 0 && server.daysUntilRenewal <= 7).length}', Icons.today_outlined),
                      _ReportMetric('30 Days', '${dueServers.length}', Icons.calendar_month_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dueServers.isEmpty)
                    const _EmptyLine('No dedicated server renewals due in the next 30 days.')
                  else
                    ...dueServers.take(8).map(_RenewalRow.new),
                ],
              ),
              _SectionCard(
                title: 'Cost & Provider Report',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.success,
                children: [
                  ..._moneyRows(_sumMoneyBy(roots, (server) => server.provider), store.monthlySpend, emptyText: 'No provider cost data available.'),
                  const Divider(height: 22),
                  ..._moneyRows(_sumMoneyBy(roots, (server) => server.assignedClient), store.monthlySpend, emptyText: 'No client cost data available.'),
                ],
              ),
              _SectionCard(
                title: 'Host & VM Allocation Report',
                icon: Icons.hub_outlined,
                color: AppColors.accent,
                children: roots.isEmpty
                    ? const [_EmptyLine('No dedicated hosts available.')]
                    : roots.map((host) => _HostAllocationRow(host: host, children: store.childrenOf(host.id))).toList(),
              ),
              _SectionCard(
                title: 'Client Allocation Report',
                icon: Icons.business_center_outlined,
                color: AppColors.danger,
                children: [
                  ..._topRows(_groupBy(store.servers, (server) => server.assignedClient), store.servers.length, emptyText: 'No client allocation data available.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({
    required this.dedicatedCount,
    required this.vmCount,
    required this.monthlySpend,
    required this.dueCount,
  });

  final int dedicatedCount;
  final int vmCount;
  final double monthlySpend;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF7C3AED), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operational Reports', style: TextStyle(color: Color(0xFFD8B4FE), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('Server estate intelligence', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _MetricGrid(
            dark: true,
            metrics: [
              _ReportMetric('Dedicated', '$dedicatedCount', Icons.dns_rounded),
              _ReportMetric('VMs', '$vmCount', Icons.developer_board_outlined),
              _ReportMetric('Monthly', 'PKR ${monthlySpend.toStringAsFixed(0)}', Icons.payments_outlined),
              _ReportMetric('Due 30d', '$dueCount', Icons.event_busy_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, this.dark = false});

  final List<_ReportMetric> metrics;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 4 ? 1.65 : 1.45,
          children: metrics.map((metric) => _MetricTile(metric: metric, dark: dark)).toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.dark});

  final _ReportMetric metric;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.13) : AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.18) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, color: dark ? const Color(0xFFBAE6FD) : AppColors.info, size: 18),
          const SizedBox(height: 6),
          Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? const Color(0xFFE0F2FE) : AppColors.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ReportMetric {
  const _ReportMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value, required this.percent});

  final String label;
  final String value;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(value, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: percent.clamp(0, 1),
              backgroundColor: AppColors.neutralSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget {
  const _RenewalRow(this.server);

  final ManagedServer server;

  @override
  Widget build(BuildContext context) {
    final days = server.daysUntilRenewal;
    final date = DateFormat('MMM d, yyyy').format(server.renewalDate);
    return _InfoLine(
      icon: days < 0 ? Icons.error_outline : Icons.event_outlined,
      title: server.name,
      subtitle: '${server.assignedClient} - $date',
      trailing: days < 0 ? '${days.abs()}d overdue' : '${days}d left',
      color: days < 0 ? AppColors.danger : AppColors.warning,
    );
  }
}

class _HostAllocationRow extends StatelessWidget {
  const _HostAllocationRow({required this.host, required this.children});

  final ManagedServer host;
  final List<ManagedServer> children;

  @override
  Widget build(BuildContext context) {
    final cpu = children.fold<int>(0, (total, server) => total + (server.vmCpuCores ?? 0));
    final ram = children.fold<double>(0, (total, server) => total + (server.vmMemoryGb ?? 0));
    final disk = children.fold<double>(0, (total, server) => total + (server.vmDiskGb ?? 0));
    return _InfoLine(
      icon: Icons.dns_rounded,
      title: host.name,
      subtitle: '${children.length} VM(s), $cpu vCPU, ${ram.toStringAsFixed(1)} GB RAM, ${disk.toStringAsFixed(1)} GB disk',
      trailing: host.provider,
      color: AppColors.accent,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(trailing, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        color: AppColors.neutralSoft,
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

List<Widget> _statusRows(List<ManagedServer> servers) {
  if (servers.isEmpty) {
    return const [_EmptyLine('No dedicated servers available.')];
  }
  return ServerStatus.values.map((status) {
    final count = _countStatus(servers, status);
    return _ReportRow(
      label: status.label,
      value: '$count',
      percent: servers.isEmpty ? 0 : count / servers.length,
    );
  }).toList();
}

List<Widget> _topRows(Map<String, int> values, int total, {required String emptyText}) {
  final rows = values.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (rows.isEmpty || total == 0) {
    return [_EmptyLine(emptyText)];
  }
  return rows.take(6).map((entry) {
    return _ReportRow(
      label: entry.key,
      value: '${entry.value}',
      percent: entry.value / total,
    );
  }).toList();
}

List<Widget> _moneyRows(Map<String, double> values, double total, {required String emptyText}) {
  final rows = values.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (rows.isEmpty || total <= 0) {
    return [_EmptyLine(emptyText)];
  }
  return rows.take(6).map((entry) {
    return _ReportRow(
      label: entry.key,
      value: 'PKR ${entry.value.toStringAsFixed(0)}',
      percent: entry.value / total,
    );
  }).toList();
}

int _countStatus(List<ManagedServer> servers, ServerStatus status) {
  return servers.where((server) => server.status == status).length;
}

Map<String, int> _groupBy(List<ManagedServer> servers, String Function(ManagedServer server) keyOf) {
  final result = <String, int>{};
  for (final server in servers) {
    final key = keyOf(server).trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = (result[key] ?? 0) + 1;
  }
  return result;
}

Map<String, double> _sumMoneyBy(List<ManagedServer> servers, String Function(ManagedServer server) keyOf) {
  final result = <String, double>{};
  for (final server in servers) {
    final key = keyOf(server).trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = (result[key] ?? 0) + server.monthlyCost;
  }
  return result;
}
