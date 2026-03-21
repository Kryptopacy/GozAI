import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:go_router/go_router.dart';

import 'firebase_options.dart';

import 'core/theme.dart';
import 'core/app_config.dart';
import 'services/gemini_live_service.dart';
import 'services/camera_service.dart';
import 'services/audio_service.dart';
import 'services/ocr_service.dart';
import 'services/screen_navigator_service.dart';
import 'services/light_meter_service.dart';
import 'services/screen_capture_service.dart';
import 'services/clinical_telemetry_service.dart';
import 'services/user_memory_service.dart';
import 'screens/home_screen.dart';
import 'screens/caregiver_dashboard.dart';
import 'screens/doctor_dashboard.dart';
import 'screens/transcripts_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration FIRST before Firebase.
  // NOTE: We use 'assets/app.env' (not '.env') because dotfiles are excluded
  // from Flutter web builds and Firebase Hosting ignores them via the '**/.*'
  // rule. A plain file under assets/ is correctly bundled and served.
  await dotenv.load(fileName: 'assets/app.env');

  // Initialize Firebase using the generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Validate configuration
  if (!AppConfig.isConfigured) {
    debugPrint('ERROR: Missing GEMINI_API_KEY in .env file');
  }

  runApp(GozAIApp());
}

/// GozAI — Premium Navigation Router
final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isGoingToProtected = state.matchedLocation == '/caregiver' || state.matchedLocation == '/doctor';

    // If unauthenticated and trying to access pro dashboards, route to login wall
    if (user == null && isGoingToProtected) {
      return '/login';
    }

    return null; // Return null to proceed
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/caregiver',
      builder: (context, state) => const CaregiverDashboard(patientUid: 'demo_patient_001'),
    ),
    GoRoute(
      path: '/doctor',
      builder: (context, state) {
        final dId = FirebaseAuth.instance.currentUser?.uid ?? 'demo_doctor_001';
        return DoctorDashboard(doctorId: dId);
      },
    ),
    GoRoute(
      path: '/transcripts',
      builder: (context, state) => const TranscriptsScreen(),
    ),
  ],
);

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
        ChangeNotifierProvider(create: (_) => ScreenCaptureService()),
        ChangeNotifierProvider(create: (_) => ClinicalTelemetryService()),
        ChangeNotifierProvider(create: (_) => UserMemoryService()),
      ],
      child: Consumer<ScreenCaptureService>(
        builder: (context, screenCapture, child) {
          return MaterialApp.router(
            title: 'GozAI',
            debugShowCheckedModeBanner: false,
            theme: GozAITheme.darkTheme,
            routerConfig: _router,

            // Accessibility configuration
            builder: (context, routerChild) {
              final content = MediaQuery(
                // Enforce minimum text scaling for accessibility
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1.0).clamp(1.0, 2.0),
                  ),
                ),
                child: routerChild!,
              );

              // Wrap the entire app UI in the screen capture boundary
              return RepaintBoundary(
                key: screenCapture.globalKey,
                child: content,
              );
            },
          );
        },
      ),
    );
  }
}
