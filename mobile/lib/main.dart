import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'app.dart';

void main() {
  if (kDebugMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(details.exceptionAsString(), style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    };
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const SmartHomeApp(),
    ),
  );
}
