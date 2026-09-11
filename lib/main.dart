import 'package:flutter/material.dart';

void main() {
  runApp(const TayyibWordApp());
}

class TayyibWordApp extends StatelessWidget {
  const TayyibWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TayyibWord',
      theme: ThemeData(
        useMaterial3: false,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185ABD)),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'TayyibWord',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
