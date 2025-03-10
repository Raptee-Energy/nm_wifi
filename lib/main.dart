import 'package:flutter/material.dart';
import 'UserInterface/NetworkScreen.dart';

void main() {
  runApp(const NetworkManagerApp());
}

class NetworkManagerApp extends StatelessWidget {
  const NetworkManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Manager',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const NetworkScreen(),
    );
  }
}
