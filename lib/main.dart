import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/renewal_notification_service.dart';
import 'services/server_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RenewalNotificationService.instance.initialize();
  final store = ServerStore();
  await store.load();
  runApp(ServerManagerApp(store: store));
}

class ServerManagerApp extends StatelessWidget {
  const ServerManagerApp({super.key, required this.store});

  final ServerStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Server Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(store: store),
    );
  }
}
