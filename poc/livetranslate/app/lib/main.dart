import 'package:flutter/material.dart';

import 'translate_screen.dart';

void main() => runApp(const LiveTranslateApp());

class LiveTranslateApp extends StatelessWidget {
  const LiveTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Translate PoC',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const ConversationScreen(),
    );
  }
}
