import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/app_config.dart';
import 'services/gemini_live_service.dart';
import 'services/camera_service.dart';
import 'services/audio_service.dart';
import 'services/ocr_service.dart';
import 'services/screen_navigator_service.dart';
import 'services/light_meter_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration
  await dotenv.load(fileName: '.env');

  // Validate configuration
  if (!AppConfig.isConfigured) {
    debugPrint('ERROR: Missing GEMINI_API_KEY in .env file');
  }

  runApp(const GozAIApp());
}

/// GozAI — AI Accessibility Copilot for Low-Vision Patients
class GozAIApp extends StatelessWidget {
  const GozAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeminiLiveService()),
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => OcrService()),
        ChangeNotifierProvider(create: (_) => ScreenNavigatorService()),
        ChangeNotifierProvider(create: (_) => LightMeterService()),
      ],
      child: MaterialApp(
        title: 'GozAI',
        debugShowCheckedModeBanner: false,
        theme: GozAITheme.darkTheme,
        home: const HomeScreen(),

        // Accessibility configuration
        builder: (context, child) {
          return MediaQuery(
            // Enforce minimum text scaling for accessibility
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0).clamp(1.0, 2.0),
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
