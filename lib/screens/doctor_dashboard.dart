import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// Doctor Dashboard — Pro Clinical Intelligence Aesthetic
/// Obsidian background, Bioluminescent Malachite Green accents.
/// Data-dense, breathable analytics for sighted medical professionals.
class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: GozAITheme.proTheme,
      child: Scaffold(
        backgroundColor: GozAITheme.obsidian,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Clinical Insights'),
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
              center: Alignment.topRight,
              radius: 1.8,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.07),
                GozAITheme.obsidian,
                const Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
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
                        'Weekly Patient Analytics',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated just now · AI-derived clinical telemetry',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 36),

                  // Key Metrics Row
                  const Row(
                    children: [
                      Expanded(
                        child: _ClinicalDataCard(
                          title: 'Avg Session Time',
                          value: '42m 15s',
                          trend: '+12% vs last week',
                          isPositiveTrend: true,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _ClinicalDataCard(
                          title: 'Interactions',
                          value: '143',
                          trend: '+5% vs last week',
                          isPositiveTrend: true,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _ClinicalDataCard(
                          title: 'Light Warnings',
                          value: '2',
                          trend: '−3 vs last week',
                          isPositiveTrend: true,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _ClinicalDataCard(
                          title: 'OCR Assists',
                          value: '84',
                          trend: '+21% vs last week',
                          isPositiveTrend: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Section Header
                  Row(
                    children: [
                      Icon(Icons.biotech_rounded, size: 16, color: GozAITheme.malachite),
                      const SizedBox(width: 8),
                      Text(
                        'FLAGGED CLINICAL EVENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GozAITheme.malachite,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFlaggedEventsTable(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlaggedEventsTable(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: GozAITheme.malachiteFaint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GozAITheme.proBorderGlow, width: 1),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('patients')
                .doc('demo_patient_001')
                .collection('clinical_events')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator(color: GozAITheme.malachite)),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('Error loading telemetry: ${snapshot.error}',
                        style: const TextStyle(color: GozAITheme.hazardAlert)),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text('No recent clinical events logged.',
                        style: TextStyle(color: GozAITheme.textSecondary)),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    GozAITheme.malachite.withValues(alpha: 0.06),
                  ),
                  headingTextStyle: const TextStyle(
                    color: GozAITheme.malachite,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  dataTextStyle: const TextStyle(color: GozAITheme.textPrimary, fontSize: 13),
                  dividerThickness: 1,
                  columns: const [
                    DataColumn(label: Text('DATE / TIME')),
                    DataColumn(label: Text('EVENT TYPE')),
                    DataColumn(label: Text('CLINICAL NOTE')),
                    DataColumn(label: Text('SEVERITY')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final time = data['timestamp'] as Timestamp?;
                    final formattedTime = time != null
                        ? _formatTimestamp(time.toDate())
                        : 'Just now';
                    return _buildRow(
                      formattedTime,
                      data['type'] ?? 'Unknown',
                      data['note'] ?? '',
                      data['severity'] ?? 'Medium',
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$m';
  }

  DataRow _buildRow(String time, String type, String note, String severity) {
    final Color severityColor;
    switch (severity) {
      case 'High':   severityColor = GozAITheme.hazardAlert;  break;
      case 'Medium': severityColor = const Color(0xFFFFAA00); break;
      default:       severityColor = GozAITheme.malachite;    break;
    }
    return DataRow(
      cells: [
        DataCell(Text(time, style: const TextStyle(color: GozAITheme.textSecondary, fontFeatures: [FontFeature.tabularFigures()]))),
        DataCell(Text(
          type.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(color: GozAITheme.malachite, fontWeight: FontWeight.w600),
        )),
        DataCell(SizedBox(
          width: 220,
          child: Text(note, style: const TextStyle(color: GozAITheme.textSecondary, height: 1.3), overflow: TextOverflow.ellipsis, maxLines: 2),
        )),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: severityColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              severity,
              style: TextStyle(fontSize: 11, color: severityColor, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClinicalDataCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositiveTrend;

  const _ClinicalDataCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositiveTrend,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GozAITheme.malachiteFaint,
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GozAITheme.textPrimary,
                  letterSpacing: -1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositiveTrend ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 14,
                    color: isPositiveTrend ? GozAITheme.malachite : GozAITheme.hazardAlert,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        color: isPositiveTrend ? GozAITheme.malachite : GozAITheme.hazardAlert,
                        fontWeight: FontWeight.w500,
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
