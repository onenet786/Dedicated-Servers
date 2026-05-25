import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/server_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ServerStore();
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
      home: _AppLoader(store: store),
    );
  }
}

class _AppLoader extends StatefulWidget {
  const _AppLoader({required this.store});

  final ServerStore store;

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(store: widget.store);
  }
}
