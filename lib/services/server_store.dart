import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/server.dart';
import 'renewal_notification_service.dart';
import 'server_api.dart';
import 'server_database.dart';

class ServerStore extends ChangeNotifier {
  ServerStore({
    ServerDatabase? database,
    ServerApi? api,
    RenewalNotificationService? notificationService,
  })
      : _database = database ?? ServerDatabase.instance,
        _api = api ?? ServerApi(),
        _notificationService =
            notificationService ?? RenewalNotificationService.instance;

  final ServerDatabase _database;
  final ServerApi _api;
  final RenewalNotificationService _notificationService;
  final List<ManagedServer> _servers = [];
  final _uuid = const Uuid();

  List<ManagedServer> get servers => List.unmodifiable(_servers);

  List<ManagedServer> get rootServers {
    return _servers.where((server) => server.parentId == null).toList();
  }

  List<ManagedServer> childrenOf(String parentId) {
    return _servers.where((server) => server.parentId == parentId).toList();
  }

  Future<void> load() async {
    await _deletePreloadedServers();
    final savedServers = await _loadServers();
    _servers
      ..clear()
      ..addAll(savedServers);

    await _notificationService.syncServerReminders(_servers);
    notifyListeners();
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

    try {
      final remoteServers = await _api.fetchServers();
      await _database.replaceServers(remoteServers);
      return remoteServers;
    } catch (_) {
      return _database.fetchServers();
    }
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
