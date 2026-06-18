import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';

void main() {
  // Riverpod 전역 ProviderScope로 앱을 감싼다.
  runApp(const ProviderScope(child: DtxApp()));
}

/// 도박중독 DTx PoC 앱 루트.
class DtxApp extends StatelessWidget {
  const DtxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마음 파도타기 (DTx PoC)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8FB0), // 차분한 청록 톤
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      // P0는 단순 push 기반 라우팅. 홈에서 시작.
      home: const HomeScreen(),
    );
  }
}
