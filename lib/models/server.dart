enum ServerStatus { active, dueSoon, overdue, suspended, retired }

class ManagedServer {
  const ManagedServer({
    required this.id,
    this.parentId,
    required this.name,
    required this.ipAddress,
    required this.provider,
    required this.location,
    required this.specification,
    required this.operatingSystem,
    required this.loginUser,
    required this.monthlyCost,
    required this.purchaseDate,
    required this.renewalDate,
    required this.assignedClient,
    required this.clientPhone,
    required this.status,
    required this.notes,
    this.vmCpuCores,
    this.vmMemoryGb,
    this.vmDiskGb,
    this.vmStorage,
    this.vmRole,
  });

  final String id;
  final String? parentId;
  final String name;
  final String ipAddress;
  final String provider;
  final String location;
  final String specification;
  final String operatingSystem;
  final String loginUser;
  final double monthlyCost;
  final DateTime purchaseDate;
  final DateTime renewalDate;
  final String assignedClient;
  final String clientPhone;
  final ServerStatus status;
  final String notes;
  final int? vmCpuCores;
  final double? vmMemoryGb;
  final double? vmDiskGb;
  final String? vmStorage;
  final String? vmRole;

  bool get isVirtualMachine => parentId != null;

  factory ManagedServer.fromMap(Map<String, Object?> map) {
    return ManagedServer(
      id: map['id'] as String,
      parentId: _readNullableString(map['parent_id']),
      name: map['name'] as String,
      ipAddress: map['ip_address'] as String,
      provider: map['provider'] as String,
      location: map['location'] as String,
      specification: map['specification'] as String,
      operatingSystem: map['operating_system'] as String,
      loginUser: map['login_user'] as String,
      monthlyCost: _readDouble(map['monthly_cost']),
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      renewalDate: DateTime.parse(map['renewal_date'] as String),
      assignedClient: map['assigned_client'] as String,
      clientPhone: (map['client_phone'] ?? '').toString(),
      status: ServerStatus.values.byName(map['status'] as String),
      notes: map['notes'] as String,
      vmCpuCores: _readNullableInt(map['vm_cpu_cores']),
      vmMemoryGb: _readNullableDouble(map['vm_memory_gb']),
      vmDiskGb: _readNullableDouble(map['vm_disk_gb']),
      vmStorage: _readNullableString(map['vm_storage']),
      vmRole: _readNullableString(map['vm_role']),
    );
  }

  int get daysUntilRenewal {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedRenewal = DateTime(
      renewalDate.year,
      renewalDate.month,
      renewalDate.day,
    );
    return normalizedRenewal.difference(normalizedToday).inDays;
  }

  bool get isRenewalUrgent => daysUntilRenewal <= 7;

  bool get needsRenewalReminder {
    if (isVirtualMachine ||
        status == ServerStatus.retired ||
        status == ServerStatus.suspended) {
      return false;
    }

    return daysUntilRenewal <= 7;
  }

  ManagedServer copyWith({
    String? id,
    Object? parentId = _unchanged,
    String? name,
    String? ipAddress,
    String? provider,
    String? location,
    String? specification,
    String? operatingSystem,
    String? loginUser,
    double? monthlyCost,
    DateTime? purchaseDate,
    DateTime? renewalDate,
    String? assignedClient,
    String? clientPhone,
    ServerStatus? status,
    String? notes,
    int? vmCpuCores,
    double? vmMemoryGb,
    double? vmDiskGb,
    Object? vmStorage = _unchanged,
    Object? vmRole = _unchanged,
  }) {
    return ManagedServer(
      id: id ?? this.id,
      parentId: parentId == _unchanged ? this.parentId : parentId as String?,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      provider: provider ?? this.provider,
      location: location ?? this.location,
      specification: specification ?? this.specification,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      loginUser: loginUser ?? this.loginUser,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      renewalDate: renewalDate ?? this.renewalDate,
      assignedClient: assignedClient ?? this.assignedClient,
      clientPhone: clientPhone ?? this.clientPhone,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      vmCpuCores: vmCpuCores ?? this.vmCpuCores,
      vmMemoryGb: vmMemoryGb ?? this.vmMemoryGb,
      vmDiskGb: vmDiskGb ?? this.vmDiskGb,
      vmStorage: vmStorage == _unchanged ? this.vmStorage : vmStorage as String?,
      vmRole: vmRole == _unchanged ? this.vmRole : vmRole as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'ip_address': ipAddress,
      'provider': provider,
      'location': location,
      'specification': specification,
      'operating_system': operatingSystem,
      'login_user': loginUser,
      'monthly_cost': monthlyCost,
      'purchase_date': purchaseDate.toIso8601String(),
      'renewal_date': renewalDate.toIso8601String(),
      'assigned_client': assignedClient,
      'client_phone': clientPhone,
      'status': status.name,
      'notes': notes,
      'vm_cpu_cores': vmCpuCores,
      'vm_memory_gb': vmMemoryGb,
      'vm_disk_gb': vmDiskGb,
      'vm_storage': vmStorage,
      'vm_role': vmRole,
    };
  }
}

const _unchanged = Object();

String? _readNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
}

int? _readNullableInt(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double? _readNullableDouble(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

extension ServerStatusLabel on ServerStatus {
  String get label {
    switch (this) {
      case ServerStatus.active:
        return 'Active';
      case ServerStatus.dueSoon:
        return 'Due Soon';
      case ServerStatus.overdue:
        return 'Overdue';
      case ServerStatus.suspended:
        return 'Suspended';
      case ServerStatus.retired:
        return 'Retired';
    }
  }
}
