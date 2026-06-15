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
    await update(
      server.copyWith(
        billingHistory: _appendBillingEvent(
          server,
          BillingEvent(
            type: 'invoice_sent',
            date: DateTime.now(),
            amount: server.monthlyCost,
            message: 'Invoice sent for ${_dateText(server.renewalDate)}',
          ),
        ),
      ),
    );
  }

  Future<ManagedServer> markPaymentReceived(ManagedServer server) async {
    final phone = _normalizeWhatsAppPhone(server.clientPhone);
    if (phone.isEmpty) {
      throw const WhatsAppApiException('Add a client WhatsApp phone first.');
    }

    final updatedServer = server.copyWith(
      renewalDate: _nextMonthlyDueDate(server.renewalDate),
      status: ServerStatus.active,
      billingHistory: _appendBillingEvent(
        server,
        BillingEvent(
          type: 'payment_received',
          date: DateTime.now(),
          amount: server.monthlyCost,
          message: 'Payment received',
          nextDueDate: _nextMonthlyDueDate(server.renewalDate),
        ),
      ),
    );
    await update(updatedServer);
    await _whatsAppApi.sendMessage(
      phone: phone,
      clientName: updatedServer.assignedClient,
      message: _paymentReceivedMessage(server, updatedServer.renewalDate),
    );
    return updatedServer;
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
      'Monthly cost: PKR ${server.monthlyCost.toStringAsFixed(2)}\n\n'
      'Please arrange renewal to avoid service interruption.\n\n'
      'Best regards,';
}

String _paymentReceivedMessage(ManagedServer server, DateTime nextDueDate) {
  final paidUntil = _dateText(server.renewalDate);
  final nextDue = _dateText(nextDueDate);

  return '*Dear ${server.assignedClient},*\n\n'
      'Thank you. We have received your payment for *${server.name}*.\n'
      'Server IP: ${_firstIp(server.ipAddress)}\n'
      'Amount received: PKR ${server.monthlyCost.toStringAsFixed(2)}\n'
      'Paid until: $paidUntil\n'
      'Next payment due date: $nextDue\n\n'
      'Best regards,';
}

List<BillingEvent> _appendBillingEvent(ManagedServer server, BillingEvent event) {
  return [event, ...server.billingHistory].take(20).toList();
}

String _dateText(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _nextMonthlyDueDate(DateTime currentDueDate) {
  final nextMonth = currentDueDate.month + 1;
  final nextYear = currentDueDate.year + ((nextMonth - 1) ~/ 12);
  final normalizedMonth = ((nextMonth - 1) % 12) + 1;
  final lastDay = DateTime(nextYear, normalizedMonth + 1, 0).day;
  final day = currentDueDate.day > lastDay ? lastDay : currentDueDate.day;
  return DateTime(nextYear, normalizedMonth, day);
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
  final date = server.renewalDate;
  final renewalDate = '${date.day} ${_monthName(date.month)} ${date.year}';
  final monthYear = '${_monthName(date.month)} ${date.year}';
  final shortId = server.id.substring(0, server.id.length < 5 ? server.id.length : 5);
  final invoiceNo = 'OneNetSol$shortId';
  final amountNumber = _formatWholeCurrency(server.monthlyCost);
  final amount = 'PKR$amountNumber';
  final client = server.assignedClient.trim().isEmpty
      ? 'Client'
      : server.assignedClient.trim();
  final location = server.location.trim();
  final content = StringBuffer();

  _pdfRectFill(content, 13, 802, 265, 22, '0.945 0.353 0.027');
  _pdfRectFill(content, 378, 802, 217, 22, '0.502 0.839 0.129');

  const badgeX = 278.0;
  const badgeY = 789.0;
  const badgeW = 100.0;
  const badgeH = 38.0;
  _pdfRectFill(content, badgeX, badgeY, badgeW, badgeH, '1 1 1');
  _pdfRectStroke(content, badgeX, badgeY, badgeW, badgeH, '0.945 0.353 0.027');
  _pdfText(content, 'Invoice', 288, 801, 24, '/F1', '0.247 0.737 0.027');

  _pdfText(content, 'OneNet Solutions', 20, 748, 10, '/F1B', '0.247 0.737 0.027');
  _pdfText(content, 'NTN# 1443348-6&', 20, 733, 11);
  _pdfText(content, '&', 20, 718, 11);
  _pdfText(content, 'Shop No.1, 83-D, The Mall,&', 20, 704, 11);
  _pdfText(content, 'Lahore', 20, 690, 11);
  _pdfText(content, '+923214424625', 20, 676, 11);

  _pdfText(content, 'ONE', 256, 733, 23, '/F1B', '0.345 0.753 0.816');
  _pdfText(content, 'NET', 306, 733, 23, '/F1B', '0.345 0.753 0.816');
  _pdfText(content, 'SOLUTIONS', 266, 720, 9, '/F1B', '0.65 0.65 0.65');

  _pdfText(content, 'Dated:', 410, 748, 11);
  _pdfText(content, renewalDate, 500, 748, 11);
  _pdfText(content, 'Invoice No.:', 410, 733, 11);
  _pdfText(content, invoiceNo, 500, 733, 11);

  _pdfText(content, 'Bill To:', 20, 633, 11, '/F1B', '0.247 0.737 0.027');
  _pdfText(content, client, 20, 619, 11);
  _pdfText(content, server.name, 20, 605, 11);
  if (location.isNotEmpty) {
    _pdfText(content, location, 20, 591, 11);
  }

  const tableLeft = 13.0;
  const tableRight = 595.0;
  const tableTop = 565.0;
  const tableBottom = 68.0;
  const qtyX = 57.0;
  const descX = 417.0;
  const unitX = 506.0;

  _pdfRectStroke(content, tableLeft, tableBottom, tableRight - tableLeft,
      tableTop - tableBottom, '0 0 0');
  _pdfLine(content, tableLeft, 541, tableRight, 541, '0 0 0');
  _pdfLine(content, qtyX, tableTop, qtyX, tableBottom, '0 0 0');
  _pdfLine(content, descX, tableTop, descX, tableBottom, '0 0 0');
  _pdfLine(content, unitX, tableTop, unitX, tableBottom, '0 0 0');

  _pdfTextRight(content, 'Qty', 51, 552, 10, '/F1B', '0.247 0.737 0.027');
  _pdfText(content, 'Description', 62, 552, 10, '/F1B', '0.247 0.737 0.027');
  _pdfTextRight(content, 'Unit Price', 499, 552, 10, '/F1B', '0.247 0.737 0.027');
  _pdfTextRight(content, 'Total', 589, 552, 10, '/F1B', '0.247 0.737 0.027');

  _pdfTextRight(content, '1', 52, 526, 10);
  _pdfText(
    content,
    'Monthly Services Charges for the Month of $monthYear',
    62,
    526,
    10,
  );
  _pdfTextRight(content, amount, 499, 526, 10);
  _pdfTextRight(content, amount, 589, 526, 10);

  _pdfTextRight(content, 'Total', 523, 49, 10, '/F1B');
  _pdfTextRight(content, amount, 590, 49, 10, '/F1B');
  _pdfTextRight(content, 'Grand Total', 523, 32, 10, '/F1B');
  _pdfTextRight(content, amount, 590, 32, 10, '/F1B');
  _pdfText(content, 'Thank you for your business.', 14, 8, 11, '/F1B');

  return base64Encode(_simplePdf(content.toString()));
}

List<int> _simplePdf(String content) {
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Resources << /Font << /F1 4 0 R /F1B 6 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n',
    '6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
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

void _pdfText(
  StringBuffer content,
  String text,
  num x,
  num y,
  num size, [
  String font = '/F1',
  String color = '0 0 0',
]) {
  content
    ..write('BT\n')
    ..write('$color rg\n')
    ..write('$font $size Tf\n')
    ..write('$x $y Td\n')
    ..write('(${_pdfEscape(text)}) Tj\n')
    ..write('ET\n');
}

void _pdfTextRight(
  StringBuffer content,
  String text,
  num right,
  num y,
  num size, [
  String font = '/F1',
  String color = '0 0 0',
]) {
  final width = _pdfApproxTextWidth(text, size);
  _pdfText(content, text, right - width, y, size, font, color);
}

double _pdfApproxTextWidth(String text, num size) {
  var units = 0.0;
  for (final codeUnit in text.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    units += RegExp(r'[ilI1., ]').hasMatch(char) ? 0.28 : 0.56;
  }
  return units * size;
}

void _pdfRectFill(
  StringBuffer content,
  num x,
  num y,
  num width,
  num height,
  String color,
) {
  content.write('$color rg\n$x $y $width $height re\nf\n');
}

void _pdfRectStroke(
  StringBuffer content,
  num x,
  num y,
  num width,
  num height,
  String color,
) {
  content.write('$color RG\n$x $y $width $height re\nS\n');
}

void _pdfLine(
  StringBuffer content,
  num x1,
  num y1,
  num x2,
  num y2,
  String color,
) {
  content.write('$color RG\n$x1 $y1 m\n$x2 $y2 l\nS\n');
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

String _formatWholeCurrency(double value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
