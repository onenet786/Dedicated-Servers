import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/server.dart';
import 'renewal_notification_service.dart';
import 'server_api.dart';
import 'server_database.dart';
import 'whatsapp_api.dart';

class ServerStore extends ChangeNotifier {
  ServerStore({
    ServerDatabase? database,
    ServerApi? api,
    WhatsAppApi? whatsAppApi,
    RenewalNotificationService? notificationService,
  })
      : _database = database ?? ServerDatabase.instance,
        _api = api ?? ServerApi(),
        _whatsAppApi = whatsAppApi ?? WhatsAppApi(),
        _notificationService =
            notificationService ?? RenewalNotificationService.instance;

  final ServerDatabase _database;
  final ServerApi _api;
  final WhatsAppApi _whatsAppApi;
  final RenewalNotificationService _notificationService;
  final List<ManagedServer> _servers = [];
  final _uuid = const Uuid();
  String? _loadError;

  List<ManagedServer> get servers => List.unmodifiable(_servers);

  String? get loadError => _loadError;

  List<ManagedServer> get rootServers {
    return _servers.where((server) => server.parentId == null).toList();
  }

  List<ManagedServer> childrenOf(String parentId) {
    return _servers.where((server) => server.parentId == parentId).toList();
  }

  Future<void> load() async {
    try {
      await _deletePreloadedServers();
      final savedServers = await _loadServers();
      _servers
        ..clear()
        ..addAll(savedServers);
      _loadError = null;

      await _notificationService.syncServerReminders(_servers);
    } catch (error) {
      final cachedServers = await _database.fetchServers();
      _servers
        ..clear()
        ..addAll(cachedServers);
      _loadError = error.toString();
      await _notificationService.syncServerReminders(_servers);
    } finally {
      notifyListeners();
    }
  }

  List<ManagedServer> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return rootServers;
    }

    return _servers.where((server) {
      final content = [
        server.name,
        server.ipAddress,
        server.provider,
        server.location,
        server.specification,
        server.operatingSystem,
        server.assignedClient,
        server.status.label,
      ].join(' ').toLowerCase();
      return content.contains(normalizedQuery);
    }).toList();
  }

  ManagedServer? byId(String id) {
    for (final server in _servers) {
      if (server.id == id) {
        return server;
      }
    }
    return null;
  }

  Future<void> add(ManagedServer server) async {
    final serverWithId = server.copyWith(id: _uuid.v4());
    await _saveRemote(serverWithId);
    await _database.insertServer(serverWithId);
    _servers.insert(0, serverWithId);
    await _notificationService.syncServerReminders(_servers);
    notifyListeners();
  }

  Future<void> update(ManagedServer updatedServer) async {
    final index = _servers.indexWhere((server) => server.id == updatedServer.id);
    if (index == -1) {
      return;
    }
    await _saveRemote(updatedServer);
    await _database.updateServer(updatedServer);
    _servers[index] = updatedServer;
    await _notificationService.syncServerReminders(_servers);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final removedIds = _servers
        .where((server) => server.id == id || server.parentId == id)
        .map((server) => server.id)
        .toList();
    await _deleteRemote(id);
    await _database.deleteServer(id);
    _servers.removeWhere((server) => server.id == id || server.parentId == id);
    for (final removedId in removedIds) {
      await _notificationService.cancelServerReminder(removedId);
    }
    notifyListeners();
  }

  Future<void> sendWhatsAppMessage(ManagedServer server) async {
    final phone = _normalizeWhatsAppPhone(server.clientPhone);
    if (phone.isEmpty) {
      throw const WhatsAppApiException('Add a client WhatsApp phone first.');
    }

    await _whatsAppApi.sendMessage(
      phone: phone,
      clientName: server.assignedClient,
      message: _whatsAppMessage(server),
      pdfBase64: _invoicePdfBase64(server),
      pdfFileName: _invoiceFileName(server),
    );
  }

  double get monthlySpend {
    return rootServers.fold(0, (total, server) => total + server.monthlyCost);
  }

  int get urgentRenewals {
    return rootServers.where((server) => server.isRenewalUrgent).length;
  }

  int get clientCount {
    return _servers.map((server) => server.assignedClient).toSet().length;
  }

  int get vmCount {
    return _servers.where((server) => server.isVirtualMachine).length;
  }

  Future<List<ManagedServer>> _loadServers() async {
    if (!AppConfig.hasRemoteApi || !_api.isConfigured) {
      return _database.fetchServers();
    }

    final remoteServers = await _api.fetchServers();
    await _database.replaceServers(remoteServers);
    return remoteServers;
  }

  Future<void> _deletePreloadedServers() async {
    for (final id in _preloadedServerIds) {
      try {
        await _deleteRemote(id);
        await _database.deleteServer(id);
      } catch (_) {
        await _database.deleteServer(id);
      }
    }
  }

  Future<void> _saveRemote(ManagedServer server) async {
    if (AppConfig.hasRemoteApi && _api.isConfigured) {
      await _api.saveServer(server);
    }
  }

  Future<void> _deleteRemote(String id) async {
    if (AppConfig.hasRemoteApi && _api.isConfigured) {
      await _api.deleteServer(id);
    }
  }
}

const _preloadedServerIds = ['srv-1', 'srv-2', 'srv-3'];

String _normalizeWhatsAppPhone(String phone) {
  return phone.replaceAll(RegExp(r'\D'), '');
}

String _whatsAppMessage(ManagedServer server) {
  final renewalDate =
      '${server.renewalDate.year}-${server.renewalDate.month.toString().padLeft(2, '0')}-${server.renewalDate.day.toString().padLeft(2, '0')}';

  if (server.isVirtualMachine) {
    return '*Dear ${server.assignedClient},*\n\n'
        'Server details for *${server.name}*:\n'
        'IP: ${_firstIp(server.ipAddress)}\n'
        'OS: ${server.operatingSystem}\n'
        'Specs: ${server.specification}\n\n'
        'Best regards,';
  }

  final days = server.daysUntilRenewal;
  final dueText = days < 0
      ? 'was due ${days.abs()} day(s) ago'
      : 'is due in $days day(s)';

  return '*Dear ${server.assignedClient},*\n\n'
      'Your server renewal for *${server.name}* ($renewalDate) $dueText.\n'
      'Server IP: ${_firstIp(server.ipAddress)}\n'
      'Invoice amount: PKR ${server.monthlyCost.toStringAsFixed(2)}\n\n'
      'Invoice PDF is attached. Please arrange renewal to avoid service interruption.\n\n'
      'Best regards,';
}

String _firstIp(String ipAddress) {
  return ipAddress.split(RegExp(r'[,;\s]+')).firstWhere(
        (part) => part.trim().isNotEmpty,
        orElse: () => ipAddress,
      );
}

String _invoiceFileName(ManagedServer server) {
  final safeName = server.assignedClient
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final date =
      '${server.renewalDate.year}${server.renewalDate.month.toString().padLeft(2, '0')}${server.renewalDate.day.toString().padLeft(2, '0')}';
  return 'OneNetSol_${safeName.isEmpty ? 'Client' : safeName}_$date.pdf';
}

String _invoicePdfBase64(ManagedServer server) {
  final renewalDate =
      '${server.renewalDate.year}-${server.renewalDate.month.toString().padLeft(2, '0')}-${server.renewalDate.day.toString().padLeft(2, '0')}';
  final invoiceNo = 'OneNetSol-${server.id.substring(0, server.id.length < 8 ? server.id.length : 8)}';
  final amount = 'PKR ${server.monthlyCost.toStringAsFixed(2)}';
  final lines = [
    const _PdfLine('OneNet Solutions Pakistan', 50, 790, 18),
    const _PdfLine('INVOICE', 455, 790, 20),
    _PdfLine('Invoice No: $invoiceNo', 50, 750, 11),
    _PdfLine('Invoice Date: $renewalDate', 50, 734, 11),
    _PdfLine('Bill To: ${server.assignedClient}', 50, 704, 12),
    const _PdfLine('Server Renewal Invoice', 50, 660, 14),
    const _PdfLine('Description', 55, 625, 11),
    const _PdfLine('Amount', 470, 625, 11),
    _PdfLine('Renewal for ${server.name}', 55, 595, 11),
    _PdfLine('Server IP: ${_firstIp(server.ipAddress)}', 55, 579, 11),
    _PdfLine('Provider: ${server.provider}', 55, 563, 11),
    _PdfLine(amount, 450, 595, 11),
    const _PdfLine('Total Due', 360, 520, 13),
    _PdfLine(amount, 450, 520, 13),
    const _PdfLine('Please arrange renewal to avoid service interruption.', 50, 470, 11),
    const _PdfLine('Thank you for your business.', 50, 446, 11),
  ];
  return base64Encode(_simplePdf(lines));
}

List<int> _simplePdf(List<_PdfLine> lines) {
  final content = StringBuffer('BT\n');
  for (final line in lines) {
    content
      ..write('/F1 ${line.size} Tf\n')
      ..write('${line.x} ${line.y} Td\n')
      ..write('(${_pdfEscape(line.text)}) Tj\n')
      ..write('${-line.x} ${-line.y} Td\n');
  }
  content.write('ET');

  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.write(object);
  }
  final xrefOffset = buffer.length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF');

  return ascii.encode(buffer.toString());
}

String _pdfEscape(String value) {
  return value
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

class _PdfLine {
  const _PdfLine(this.text, this.x, this.y, this.size);

  final String text;
  final int x;
  final int y;
  final int size;
}
