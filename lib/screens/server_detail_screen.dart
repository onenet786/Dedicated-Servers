import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/server.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_chip.dart';
import 'server_form_screen.dart';

class ServerDetailScreen extends StatelessWidget {
  const ServerDetailScreen({super.key, required this.store, required this.serverId});

  final ServerStore store;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final server = store.byId(serverId);

    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Server not found')),
        body: const Center(child: Text('This server record no longer exists.')),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Details'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServerFormScreen(store: store, server: server),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, server),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          server.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                      ),
                      ServerStatusChip(status: server.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(server.ipAddress, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  const SizedBox(height: 18),
                  _RenewalBanner(server: server),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Server Information',
            rows: [
              _InfoRow('Provider', server.provider),
              _InfoRow('Location', server.location),
              _InfoRow('Specification', server.specification),
              _InfoRow('Operating System', server.operatingSystem),
              _InfoRow('Login User', server.loginUser),
            ],
          ),
          _Section(
            title: 'Billing & Client',
            rows: [
              _InfoRow('Assigned Client', server.assignedClient),
              _InfoRow('Monthly Cost', '\$${server.monthlyCost.toStringAsFixed(2)}'),
              _InfoRow('Purchase Date', dateFormat.format(server.purchaseDate)),
              _InfoRow('Renewal Date', dateFormat.format(server.renewalDate)),
            ],
          ),
          _Section(
            title: 'Notes',
            rows: [_InfoRow('Details', server.notes.isEmpty ? 'No notes added.' : server.notes)],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ManagedServer server) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete server?'),
        content: Text('Delete ${server.name} from your records?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      await store.delete(server.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _RenewalBanner extends StatelessWidget {
  const _RenewalBanner({required this.server});

  final ManagedServer server;

  @override
  Widget build(BuildContext context) {
    final days = server.daysUntilRenewal;
    final text = days < 0 ? 'Renewal overdue by ${days.abs()} day(s)' : 'Renewal due in $days day(s)';
    final color = days < 0 ? const Color(0xFFDC2626) : days <= 7 ? const Color(0xFFD97706) : const Color(0xFF16A34A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
