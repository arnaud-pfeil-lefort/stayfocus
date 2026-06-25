import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/usage_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Without this, the system status/navigation bars paint an opaque strip
  // over the screen edges, hiding the most intense part of the background
  // gradient (which sits right at y=0 and y=max).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StayFocus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ).copyWith(surface: Colors.white),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const UsageScreen(),
    );
  }
}
