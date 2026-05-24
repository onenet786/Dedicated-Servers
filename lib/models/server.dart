enum ServerStatus { active, dueSoon, overdue, suspended, retired }

class ManagedServer {
  const ManagedServer({
    required this.id,
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
    required this.status,
    required this.notes,
  });

  final String id;
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
  final ServerStatus status;
  final String notes;

  factory ManagedServer.fromMap(Map<String, Object?> map) {
    return ManagedServer(
      id: map['id'] as String,
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
      status: ServerStatus.values.byName(map['status'] as String),
      notes: map['notes'] as String,
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
    if (status == ServerStatus.retired || status == ServerStatus.suspended) {
      return false;
    }

    return daysUntilRenewal <= 7;
  }

  ManagedServer copyWith({
    String? id,
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
    ServerStatus? status,
    String? notes,
  }) {
    return ManagedServer(
      id: id ?? this.id,
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
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
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
      'status': status.name,
      'notes': notes,
    };
  }
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(value.toString());
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
