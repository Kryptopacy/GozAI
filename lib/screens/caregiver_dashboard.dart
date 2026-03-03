import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
                'Recent Safety Alerts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildSafetyAlertsWindow(context),
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

  Widget _buildSafetyAlertsWindow(BuildContext context) {
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
            'Hazard & Disorientation Log',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: GozAITheme.textSecondary,
            ),
          ),
          const Divider(color: GozAITheme.borderSubtle, height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc('demo_patient_001')
                  .collection('clinical_events')
                  // Filtering for high priority caregiver alerts
                  .where('type', whereIn: ['hazard', 'wandering'])
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: GozAITheme.primaryBlue));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: GozAITheme.hazardAlert)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent safety hazards detected. Environment is secure.',
                      style: TextStyle(color: GozAITheme.textSecondary.withValues(alpha: 0.5)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isHazard = data['type'] == 'hazard';
                    final time = data['timestamp'] as Timestamp?;
                    final timeStr = time != null ? DateFormat('h:mm a, MMM d').format(time.toDate()) : 'Now';
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHazard ? GozAITheme.hazardAlert.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isHazard ? GozAITheme.hazardAlert.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isHazard ? Icons.warning_rounded : Icons.explore_off_rounded,
                            color: isHazard ? GozAITheme.hazardAlert : Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isHazard ? 'Physical Hazard' : 'Spatial Disorientation',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['note'] ?? 'Unknown event',
                                  style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
