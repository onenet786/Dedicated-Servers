import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/server.dart';
import '../services/renewal_notification_service.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_chip.dart';
import 'server_detail_screen.dart';
import 'server_form_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ServerStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final servers = widget.store.search(_query);
    final loadError = widget.store.loadError;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Servers',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Reports',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportsScreen(store: widget.store),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Test notification',
            onPressed: () => _testNotification(context),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Server'),
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
            children: [
              if (loadError != null) ...[
                _RemoteErrorBanner(message: loadError),
                const SizedBox(height: 12),
              ],
              _HeroCard(store: widget.store),
              const SizedBox(height: 18),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search IP, client, provider, specs...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Servers (${servers.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Renewals tracked',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (servers.isEmpty)
                const _EmptyState()
              else
                ...servers.map(
                  (server) => _ServerCard(
                    server: server,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ServerDetailScreen(
                          store: widget.store,
                          serverId: server.id,
                          initialServer: server,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServerFormScreen(store: widget.store),
      ),
    );
  }

  Future<void> _testNotification(BuildContext context) async {
    await RenewalNotificationService.instance.showTestNotification();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent')),
    );
  }
}

class _RemoteErrorBanner extends StatelessWidget {
  const _RemoteErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEE2E2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hosted server unavailable: $message',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.store});

  final ServerStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF0F766E), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Infrastructure Overview',
            style: TextStyle(
              color: Color(0xFFBFDBFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${store.rootServers.length} dedicated servers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric(icon: Icons.event_busy_outlined, label: 'Due soon', value: '${store.urgentRenewals}', color: AppColors.warning)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(icon: Icons.developer_board_outlined, label: 'VMs', value: '${store.vmCount}', color: const Color(0xFF22C55E))),
              const SizedBox(width: 8),
              Expanded(child: _Metric(icon: Icons.payments_outlined, label: 'Monthly', value: 'PKR ${store.monthlySpend.toStringAsFixed(0)}', color: const Color(0xFF38BDF8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFDDEAFE), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onTap});

  final ManagedServer server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    final accent = _accentForStatus(server.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.2),
                          accent.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.dns_rounded, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(server.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(_firstIp(server.ipAddress), style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  ServerStatusChip(status: server.status),
                ],
              ),
              const SizedBox(height: 14),
              Text(server.specification, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniInfo(icon: Icons.business, text: server.assignedClient)),
                  Expanded(child: _MiniInfo(icon: Icons.event, text: dateFormat.format(server.renewalDate))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _accentForStatus(ServerStatus status) {
  switch (status) {
    case ServerStatus.active:
      return AppColors.success;
    case ServerStatus.dueSoon:
      return AppColors.warning;
    case ServerStatus.overdue:
      return AppColors.danger;
    case ServerStatus.suspended:
      return AppColors.violet;
    case ServerStatus.retired:
      return AppColors.neutral;
  }
}

String _firstIp(String ipAddress) {
  return ipAddress.split(RegExp(r'[,;\s]+')).firstWhere(
        (part) => part.trim().isNotEmpty,
        orElse: () => ipAddress,
      );
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('No servers found. Add your first server to begin.')),
      ),
    );
  }
}
