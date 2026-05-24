import 'package:flutter/material.dart';

import '../models/server.dart';
import '../services/server_store.dart';

class ServerFormScreen extends StatefulWidget {
  const ServerFormScreen({super.key, required this.store, this.server});

  final ServerStore store;
  final ManagedServer? server;

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
  late DateTime _purchaseDate;
  late DateTime _renewalDate;
  late ServerStatus _status;

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _nameController = TextEditingController(text: server?.name ?? '');
    _ipController = TextEditingController(text: server?.ipAddress ?? '');
    _providerController = TextEditingController(text: server?.provider ?? '');
    _locationController = TextEditingController(text: server?.location ?? '');
    _specController = TextEditingController(text: server?.specification ?? '');
    _osController = TextEditingController(text: server?.operatingSystem ?? '');
    _loginController = TextEditingController(text: server?.loginUser ?? 'root');
    _costController = TextEditingController(text: server == null ? '' : server.monthlyCost.toStringAsFixed(2));
    _clientController = TextEditingController(text: server?.assignedClient ?? '');
    _notesController = TextEditingController(text: server?.notes ?? '');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Server' : 'Add Server')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _Field(controller: _nameController, label: 'Server Name', icon: Icons.dns_rounded),
            _Field(controller: _ipController, label: 'IP Address', icon: Icons.public, keyboardType: TextInputType.number),
            _Field(controller: _providerController, label: 'Hosting Provider', icon: Icons.cloud_queue),
            _Field(controller: _locationController, label: 'Data Center / Location', icon: Icons.location_on_outlined),
            _Field(controller: _specController, label: 'Specification', icon: Icons.memory, maxLines: 3),
            _Field(controller: _osController, label: 'Operating System', icon: Icons.terminal),
            _Field(controller: _loginController, label: 'Login User', icon: Icons.person_outline),
            _Field(controller: _costController, label: 'Monthly Cost', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
            _Field(controller: _clientController, label: 'Assigned Client', icon: Icons.business_center_outlined),
            const SizedBox(height: 8),
            _StatusPicker(value: _status, onChanged: (value) => setState(() => _status = value)),
            const SizedBox(height: 12),
            _DateTile(label: 'Purchase Date', date: _purchaseDate, onTap: () => _pickDate(isPurchase: true)),
            _DateTile(label: 'Renewal / Due Date', date: _renewalDate, onTap: () => _pickDate(isPurchase: false)),
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

    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final server = ManagedServer(
      id: widget.server?.id ?? '',
      name: _nameController.text.trim(),
      ipAddress: _ipController.text.trim(),
      provider: _providerController.text.trim(),
      location: _locationController.text.trim(),
      specification: _specController.text.trim(),
      operatingSystem: _osController.text.trim(),
      loginUser: _loginController.text.trim(),
      monthlyCost: cost,
      purchaseDate: _purchaseDate,
      renewalDate: _renewalDate,
      assignedClient: _clientController.text.trim(),
      status: _status,
      notes: _notesController.text.trim(),
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
  const _DateTile({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(label),
        subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
