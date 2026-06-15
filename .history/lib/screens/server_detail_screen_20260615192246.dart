import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/server.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_chip.dart';
import 'server_form_screen.dart';

class ServerDetailScreen extends StatefulWidget {
  const ServerDetailScreen({
    super.key,
    required this.store,
    required this.serverId,
    this.initialServer,
  });

  final ServerStore store;
  final String serverId;
  final ManagedServer? initialServer;

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.initialServer ?? widget.store.byId(widget.serverId);

    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Server not found')),
        body: const Center(child: Text('This server record no longer exists.')),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final subServers = widget.store.childrenOf(server.id);
    final isVm = server.isVirtualMachine;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Details'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServerFormScreen(store: widget.store, server: server),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (!isVm)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                      builder: (_) => ServerFormScreen(
                        store: widget.store,
                        parentServer: server,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_box_outlined),
            ),
          IconButton(
            onPressed: () => _confirmDelete(context, server),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F2FE), Color(0xFFF5F3FF), Color(0xFFFFFBEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          key: PageStorageKey<String>('server-detail-${server.id}'),
          controller: _scrollController,
          primary: false,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
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
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          server.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      ServerStatusChip(status: server.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_firstIp(server.ipAddress), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFBAE6FD))),
                  if (!isVm) ...[
                    const SizedBox(height: 18),
                    _RenewalBanner(server: server),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (isVm)
              _Section(
                title: 'VM Configuration',
                color: AppColors.info,
                rows: [
                  _InfoRow('Host Server', widget.store.byId(server.parentId ?? '')?.name ?? 'Dedicated host'),
                  _InfoRow('Operating System', server.operatingSystem),
                  _InfoRow('vCPU', server.vmCpuCores?.toString() ?? 'Not set'),
                  _InfoRow('Memory', server.vmMemoryGb == null ? 'Not set' : '${_formatNumber(server.vmMemoryGb!)} GB'),
                  _InfoRow('Disk', server.vmDiskGb == null ? 'Not set' : '${_formatNumber(server.vmDiskGb!)} GB'),
                  _InfoRow('Datastore', server.vmStorage ?? 'Not set'),
                  _InfoRow('Role / Purpose', server.vmRole ?? 'Not set'),
                  _InfoRow('Login User', server.loginUser),
                  _InfoRow('Assigned Client', server.assignedClient),
                  _InfoRow('Client WhatsApp Phone', server.clientPhone.isEmpty ? 'Not added' : server.clientPhone),
                ],
              )
            else
              const SizedBox.shrink(),
            if (isVm)
              _WhatsAppCard(store: widget.store, server: server)
            else ...[
              _Section(
                title: 'Server Information',
                color: AppColors.info,
                rows: [
                  _InfoRow('Provider', server.provider),
                  _InfoRow('Location', server.location),
                  _InfoRow('Specification', server.specification),
                  _InfoRow('Operating System / Hypervisor', server.operatingSystem),
                  _InfoRow('Login User', server.loginUser),
                ],
              ),
              _Section(
                title: 'Billing & Client',
                color: AppColors.success,
                rows: [
                  _InfoRow('Assigned Client', server.assignedClient),
                  _InfoRow('Client WhatsApp Phone', server.clientPhone.isEmpty ? 'Not added' : server.clientPhone),
                  _InfoRow('Monthly Cost', 'PKR ${server.monthlyCost.toStringAsFixed(2)}'),
                  _InfoRow('Purchase Date', dateFormat.format(server.purchaseDate)),
                  _InfoRow('Renewal Date', dateFormat.format(server.renewalDate)),
                ],
              ),
              _WhatsAppCard(store: widget.store, server: server),
              _SubServerSection(
                store: widget.store,
                parent: server,
                subServers: subServers,
              ),
            ],
            _Section(
              title: 'Notes',
              color: AppColors.violet,
              rows: [_InfoRow('Details', server.notes.isEmpty ? 'No notes added.' : server.notes)],
            ),
          ],
        ),
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
      await widget.store.delete(server.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

String _formatNumber(double value) {
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _WhatsAppCard extends StatefulWidget {
  const _WhatsAppCard({required this.store, required this.server});

  final ServerStore store;
  final ManagedServer server;

  @override
  State<_WhatsAppCard> createState() => _WhatsAppCardState();
}

class _WhatsAppCardState extends State<_WhatsAppCard> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final hasPhone = widget.server.clientPhone.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.chat_outlined, color: AppColors.success),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Send WhatsApp message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: FilledButton.icon(
                onPressed: _sending || !hasPhone ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending' : 'Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.store.sendWhatsAppMessage(widget.server);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp message sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _SubServerSection extends StatelessWidget {
  const _SubServerSection({
    required this.store,
    required this.parent,
    required this.subServers,
  });

  final ServerStore store;
  final ManagedServer parent;
  final List<ManagedServer> subServers;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sub Servers / VMs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerFormScreen(
                        store: store,
                        parentServer: parent,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add VM'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (subServers.isEmpty)
              const Text(
                'No VMs added under this server yet.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...subServers.map(
                (server) => _SubServerTile(
                  server: server,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerDetailScreen(
                        store: store,
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
    );
  }
}

class _SubServerTile extends StatelessWidget {
  const _SubServerTile({required this.server, required this.onTap});

  final ManagedServer server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.violetSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.developer_board_outlined, color: AppColors.violet),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _firstIp(server.ipAddress),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ServerStatusChip(status: server.status),
            ],
          ),
        ),
      ),
    );
  }
}

String _firstIp(String ipAddress) {
  return ipAddress.split(RegExp(r'[,;\s]+')).firstWhere(
        (part) => part.trim().isNotEmpty,
        orElse: () => ipAddress,
      );
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
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, required this.color});

  final String title;
  final List<_InfoRow> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
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
