import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/gemini_live_service.dart';

class CaregiverDashboard extends StatelessWidget {
  const CaregiverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GozAITheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Caregiver Overview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
          tooltip: 'Back to Home',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient Status',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              _buildTopMetricsRow(context),
              const SizedBox(height: 32),
              Text(
                'Recent Transcripts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildTranscriptLogWindow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopMetricsRow(BuildContext context) {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        final isConnected = gemini.isConnected;
        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Connection',
                value: isConnected ? 'Online' : 'Offline',
                icon: Icons.wifi,
                color: isConnected ? GozAITheme.success : GozAITheme.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Active Mode',
                value: gemini.currentMode.name.toUpperCase(),
                icon: Icons.visibility,
                color: GozAITheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: _MetricCard(
                title: 'Battery (Mock)',
                value: '84%',
                icon: Icons.battery_charging_full,
                color: GozAITheme.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTranscriptLogWindow(BuildContext context) {
    return Consumer<GeminiLiveService>(
      builder: (context, gemini, _) {
        // In a real app we'd keep a history list in the service. 
        // For the dashboard, we'll show the stream state or a placeholder.
        return Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GozAITheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GozAITheme.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Session Feed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: GozAITheme.textSecondary,
                ),
              ),
              const Divider(color: GozAITheme.borderSubtle, height: 32),
              Expanded(
                child: StreamBuilder<String>(
                  stream: gemini.transcriptStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (data == null || data.isEmpty) {
                      return Center(
                        child: Text(
                          'No recent activity. Waiting for patient query...',
                          style: TextStyle(color: GozAITheme.textSecondary.withValues(alpha: 0.5)),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Text(
                        data,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GozAITheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
