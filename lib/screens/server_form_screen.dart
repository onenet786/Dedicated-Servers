import 'package:flutter/material.dart';

import '../models/server.dart';
import '../services/server_store.dart';
import '../theme/app_theme.dart';

class ServerFormScreen extends StatefulWidget {
  const ServerFormScreen({
    super.key,
    required this.store,
    this.server,
    this.parentServer,
  });

  final ServerStore store;
  final ManagedServer? server;
  final ManagedServer? parentServer;

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ipController;
  late final TextEditingController _providerController;
  late final TextEditingController _locationController;
  late final TextEditingController _specController;
  late final TextEditingController _osController;
  late final TextEditingController _loginController;
  late final TextEditingController _costController;
  late final TextEditingController _clientController;
  late final TextEditingController _notesController;
  late final TextEditingController _cpuController;
  late final TextEditingController _memoryController;
  late final TextEditingController _diskController;
  late final TextEditingController _storageController;
  late final TextEditingController _roleController;
  late DateTime _purchaseDate;
  late DateTime _renewalDate;
  late ServerStatus _status;

  bool get _isEditing => widget.server != null;
  bool get _isSubServer => widget.server?.parentId != null || widget.parentServer != null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    final parent = widget.parentServer;
    _nameController = TextEditingController(text: server?.name ?? '');
    _ipController = TextEditingController(text: server?.ipAddress ?? '');
    _providerController = TextEditingController(text: server?.provider ?? parent?.provider ?? '');
    _locationController = TextEditingController(text: server?.location ?? parent?.location ?? '');
    _specController = TextEditingController(text: server?.specification ?? '');
    _osController = TextEditingController(text: server?.operatingSystem ?? '');
    _loginController = TextEditingController(text: server?.loginUser ?? 'root');
    _costController = TextEditingController(text: server == null ? '' : server.monthlyCost.toStringAsFixed(2));
    _clientController = TextEditingController(text: server?.assignedClient ?? parent?.assignedClient ?? '');
    _notesController = TextEditingController(text: server?.notes ?? '');
    _cpuController = TextEditingController(text: server?.vmCpuCores?.toString() ?? '');
    _memoryController = TextEditingController(text: server?.vmMemoryGb?.toString() ?? '');
    _diskController = TextEditingController(text: server?.vmDiskGb?.toString() ?? '');
    _storageController = TextEditingController(text: server?.vmStorage ?? '');
    _roleController = TextEditingController(text: server?.vmRole ?? '');
    _purchaseDate = server?.purchaseDate ?? DateTime.now();
    _renewalDate = server?.renewalDate ?? DateTime.now().add(const Duration(days: 30));
    _status = server?.status ?? ServerStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _providerController.dispose();
    _locationController.dispose();
    _specController.dispose();
    _osController.dispose();
    _loginController.dispose();
    _costController.dispose();
    _clientController.dispose();
    _notesController.dispose();
    _cpuController.dispose();
    _memoryController.dispose();
    _diskController.dispose();
    _storageController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Server' : _isSubServer ? 'Add Sub Server' : 'Add Server')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F2FE), Color(0xFFF5F3FF), Color(0xFFFFFBEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _FormIntro(isEditing: _isEditing, isSubServer: _isSubServer),
              const SizedBox(height: 14),
              _Field(controller: _nameController, label: _isSubServer ? 'VM Name' : 'Server Name', icon: _isSubServer ? Icons.developer_board_outlined : Icons.dns_rounded),
              _Field(controller: _ipController, label: 'IP Address', icon: Icons.public, keyboardType: TextInputType.text),
              if (!_isSubServer) ...[
                _Field(controller: _providerController, label: 'Hosting Provider', icon: Icons.cloud_queue),
                _Field(controller: _locationController, label: 'Data Center / Location', icon: Icons.location_on_outlined),
                _Field(controller: _specController, label: 'Dedicated Server Specification', icon: Icons.memory, maxLines: 3),
                _Field(controller: _osController, label: 'Host OS / Hypervisor', icon: Icons.terminal),
              ] else ...[
                _Field(controller: _osController, label: 'VM OS Type / Version', icon: Icons.terminal),
                _Field(controller: _roleController, label: 'VM Role / Purpose', icon: Icons.work_outline, required: false),
                Row(
                  children: [
                    Expanded(child: _Field(controller: _cpuController, label: 'vCPU', icon: Icons.settings_input_component, keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _Field(controller: _memoryController, label: 'RAM GB', icon: Icons.memory, keyboardType: TextInputType.number)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _Field(controller: _diskController, label: 'Disk GB', icon: Icons.storage, keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _Field(controller: _storageController, label: 'Datastore', icon: Icons.inventory_2_outlined, required: false)),
                  ],
                ),
              ],
              _Field(controller: _loginController, label: 'Login User', icon: Icons.person_outline),
              if (!_isSubServer)
                _Field(controller: _costController, label: 'Monthly Cost', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
              _Field(controller: _clientController, label: 'Assigned Client', icon: Icons.business_center_outlined),
              const SizedBox(height: 8),
              _StatusPicker(value: _status, onChanged: (value) => setState(() => _status = value)),
              if (!_isSubServer) ...[
                const SizedBox(height: 12),
                _DateTile(label: 'Purchase Date', date: _purchaseDate, color: AppColors.info, onTap: () => _pickDate(isPurchase: true)),
                _DateTile(label: 'Renewal / Due Date', date: _renewalDate, color: AppColors.warning, onTap: () => _pickDate(isPurchase: false)),
              ],
              _Field(controller: _notesController, label: 'Notes', icon: Icons.notes_outlined, maxLines: 4, required: false),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Save Changes' : 'Create Server'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isPurchase}) async {
    final initialDate = isPurchase ? _purchaseDate : _renewalDate;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDate: initialDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = pickedDate;
        } else {
          _renewalDate = pickedDate;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cost = _isSubServer ? 0.0 : double.tryParse(_costController.text.trim()) ?? 0;
    final parent = widget.parentServer;
    final vmCpu = int.tryParse(_cpuController.text.trim());
    final vmMemory = double.tryParse(_memoryController.text.trim());
    final vmDisk = double.tryParse(_diskController.text.trim());
    final vmSpec = _isSubServer
        ? _buildVmSpecification(
            cpu: vmCpu,
            memory: vmMemory,
            disk: vmDisk,
            datastore: _storageController.text.trim(),
          )
        : _specController.text.trim();
    final server = ManagedServer(
      id: widget.server?.id ?? '',
      parentId: widget.server?.parentId ?? parent?.id,
      name: _nameController.text.trim(),
      ipAddress: _ipController.text.trim(),
      provider: _isSubServer ? parent?.provider ?? _providerController.text.trim() : _providerController.text.trim(),
      location: _isSubServer ? parent?.location ?? _locationController.text.trim() : _locationController.text.trim(),
      specification: vmSpec,
      operatingSystem: _osController.text.trim(),
      loginUser: _loginController.text.trim(),
      monthlyCost: cost,
      purchaseDate: _isSubServer ? parent?.purchaseDate ?? _purchaseDate : _purchaseDate,
      renewalDate: _isSubServer ? parent?.renewalDate ?? _renewalDate : _renewalDate,
      assignedClient: _clientController.text.trim(),
      status: _status,
      notes: _notesController.text.trim(),
      vmCpuCores: _isSubServer ? vmCpu : null,
      vmMemoryGb: _isSubServer ? vmMemory : null,
      vmDiskGb: _isSubServer ? vmDisk : null,
      vmStorage: _isSubServer ? _emptyToNull(_storageController.text.trim()) : null,
      vmRole: _isSubServer ? _emptyToNull(_roleController.text.trim()) : null,
    );

    if (_isEditing) {
      await widget.store.update(server);
    } else {
      await widget.store.add(server);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _buildVmSpecification({
    required int? cpu,
    required double? memory,
    required double? disk,
    required String datastore,
  }) {
    final parts = <String>[
      if (cpu != null) '$cpu vCPU',
      if (memory != null) '${memory.toStringAsFixed(memory.truncateToDouble() == memory ? 0 : 1)}GB RAM',
      if (disk != null) '${disk.toStringAsFixed(disk.truncateToDouble() == disk ? 0 : 1)}GB disk',
      if (datastore.isNotEmpty) 'Datastore: $datastore',
    ];
    return parts.isEmpty ? 'Virtual machine' : parts.join(', ');
  }

  String? _emptyToNull(String value) => value.isEmpty ? null : value;
}

class _FormIntro extends StatelessWidget {
  const _FormIntro({required this.isEditing, required this.isSubServer});

  final bool isEditing;
  final bool isSubServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storage_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? 'Update server inventory details'
                  : isSubServer
                      ? 'Create a VM or sub server under this dedicated host'
                      : 'Create a new managed server record',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.icon, this.maxLines = 1, this.keyboardType, this.required = true});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (value) {
          if (!required) {
            return null;
          }
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final ServerStatus value;
  final ValueChanged<ServerStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ServerStatus>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Server Status', prefixIcon: Icon(Icons.fact_check_outlined)),
      items: ServerStatus.values.map((status) {
        return DropdownMenuItem(value: status, child: Text(status.label));
      }).toList(),
      onChanged: (status) {
        if (status != null) {
          onChanged(status);
        }
      },
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.color, required this.onTap});

  final String label;
  final DateTime date;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calendar_month_outlined, color: color),
        ),
        title: Text(label),
        subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
