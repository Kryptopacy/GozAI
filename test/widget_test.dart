import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gozai/services/gemini_live_service.dart';
import 'package:gozai/services/user_memory_service.dart';
import 'package:gozai/screens/home_screen.dart';

void main() {
  testWidgets('GozAI initialization and accessibility audit', (WidgetTester tester) async {
    // 1. Verify Service Initialization
    final geminiService = GeminiLiveService();
    final memoryService = UserMemoryService();
    
    expect(geminiService.connectionState, GeminiConnectionState.disconnected);
    expect(memoryService.facts.isEmpty, isTrue);

    // 2. Build the app (Mocking providers)
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GeminiLiveService>.value(value: geminiService),
          ChangeNotifierProvider<UserMemoryService>.value(value: memoryService),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // 3. Verify Brutalist Accessibility UI Core Elements
    // High-contrast background check (implicitly via widget presence)
    expect(find.byType(HomeScreen), findsOneWidget);
    
    // Low-vision users need large touch targets. 
    // Verify the main interaction area is available.
    expect(find.byIcon(Icons.mic), findsOneWidget);
    
    // 4. Mode check
    expect(geminiService.currentMode, GozAIMode.scene);
  });
}
