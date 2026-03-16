import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/gemini_live_service.dart';
import '../services/sos_service.dart';

/// Caregiver Dashboard — Pro Aesthetic
/// Obsidian background, Bioluminescent Malachite Green accents.
/// Sleek, data-dense, glassmorphic. Designed for fully-sighted caregiver users.
class CaregiverDashboard extends StatelessWidget {
  const CaregiverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: GozAITheme.proTheme,
      child: Scaffold(
        backgroundColor: GozAITheme.obsidian,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Caregiver Overview'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: GozAITheme.malachite),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.8,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.08),
                GozAITheme.obsidian,
                const Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: GozAITheme.malachite,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(color: GozAITheme.malachite.withValues(alpha: 0.6), blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Patient Status',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live monitoring — updates in real time',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildSosAlertBanner(context),
                  const SizedBox(height: 16),
                  _buildTopMetricsRow(context),
                  const SizedBox(height: 32),
                  Text(
                    'Safety & Hazard Log',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hazards and spatial disorientation events',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildSafetyAlertsWindow(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosAlertBanner(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc('demo_patient_001')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink(); // No alert document
        }

        final data = snapshot.data!.data()!;
        final resolved = data['resolved'] == true;
        if (resolved) {
          return const SizedBox.shrink(); // Alert is resolved
        }

        final message = data['message'] ?? data['note'] ?? 'Emergency assistance requested.';
        final severity = data['severity'] ?? 'critical';
        final isCritical = severity.toString().toLowerCase() == 'critical' || severity.toString().toLowerCase() == 'high';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GozAITheme.hazardAlert.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GozAITheme.hazardAlert, width: 2),
            boxShadow: [
              BoxShadow(
                color: GozAITheme.hazardAlert.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: GozAITheme.hazardAlert, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCritical ? 'CRITICAL SOS ALERT' : 'PATIENT ASSISTANCE NEEDED',
                      style: const TextStyle(
                        color: GozAITheme.hazardAlert,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      context.read<SosService>().resolveAlert(userId: 'demo_patient_001');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: GozAITheme.hazardAlert,
                      side: const BorderSide(color: GozAITheme.hazardAlert),
                    ),
                    child: const Text('DISMISS'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to full map or initiate call
                    },
                    icon: const Icon(Icons.location_on, color: Colors.white),
                    label: const Text('LOCATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GozAITheme.hazardAlert,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
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
                icon: Icons.circle,
                color: isConnected ? GozAITheme.malachite : GozAITheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Active Mode',
                value: gemini.currentMode.name.toUpperCase(),
                icon: Icons.visibility_rounded,
                color: GozAITheme.malachite,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _MetricCard(
                title: 'Battery',
                value: '84%',
                icon: Icons.battery_charging_full_rounded,
                color: GozAITheme.malachite,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSafetyAlertsWindow(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 280),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GozAITheme.malachiteFaint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GozAITheme.proBorderGlow, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: GozAITheme.malachite),
                  const SizedBox(width: 8),
                  Text(
                    'HAZARD & DISORIENTATION LOG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: GozAITheme.malachite,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Divider(color: GozAITheme.malachite.withValues(alpha: 0.2), height: 28, thickness: 1),
              SizedBox(
                height: 280,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('patients')
                      .doc('demo_patient_001')
                      .collection('clinical_events')
                      .where('type', whereIn: ['hazard', 'wandering'])
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: GozAITheme.malachite));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: GozAITheme.hazardAlert)),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: GozAITheme.malachite.withValues(alpha: 0.4), size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Environment is secure',
                              style: TextStyle(
                                  color: GozAITheme.textSecondary.withValues(alpha: 0.7), fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isHazard = data['type'] == 'hazard';
                        final time = data['timestamp'] as Timestamp?;
                        final timeStr = time != null
                            ? _formatTimestamp(time.toDate())
                            : 'Just now';
                        return _AlertRow(
                          isHazard: isHazard,
                          note: data['note'] ?? 'Unknown event',
                          timeStr: timeStr,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '$h:$m $ampm, ${months[dt.month - 1]} ${dt.day}';
  }
}

class _AlertRow extends StatelessWidget {
  final bool isHazard;
  final String note;
  final String timeStr;

  const _AlertRow({required this.isHazard, required this.note, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final accent = isHazard ? GozAITheme.hazardAlert : const Color(0xFFFFAA00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHazard ? Icons.warning_rounded : Icons.explore_off_rounded,
              color: accent,
              size: 16,
            ),
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
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13, color: accent),
                    ),
                    Text(timeStr,
                        style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(note,
                    style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 13, height: 1.4)),
              ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GozAITheme.malachiteFaint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GozAITheme.proBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: GozAITheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
