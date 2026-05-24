import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/server.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_chip.dart';
import 'server_detail_screen.dart';
import 'server_form_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Servers',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Server'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
          children: [
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
                        color: Colors.grey.shade600,
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
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.store});

  final ServerStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Infrastructure Overview',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${store.servers.length} managed servers',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric(icon: Icons.event_busy_outlined, label: 'Due soon', value: '${store.urgentRenewals}', color: AppColors.warning)),
              Expanded(child: _Metric(icon: Icons.business_center_outlined, label: 'Clients', value: '${store.clientCount}', color: AppColors.accent)),
              Expanded(child: _Metric(icon: Icons.payments_outlined, label: 'Monthly', value: '\$${store.monthlySpend.toStringAsFixed(0)}', color: AppColors.info)),
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
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
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
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dns_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(server.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(server.ipAddress, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
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
