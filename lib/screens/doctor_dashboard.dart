import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

/// Doctor Dashboard — Pro Clinical Intelligence Aesthetic
/// Displays a robust roster of assigned patients and allows drill-down.
class DoctorDashboard extends StatefulWidget {
  final String doctorId;

  // Defaults to a demo doctor UID if unauthenticated (for now)
  const DoctorDashboard({super.key, this.doctorId = 'demo_doctor_001'});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String? _selectedPatientId;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: GozAITheme.proTheme,
      child: Scaffold(
        backgroundColor: GozAITheme.obsidian,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            _selectedPatientId == null ? 'Clinical Roster' : 'Patient Telemetry',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: GozAITheme.malachite),
            onPressed: () {
              if (_selectedPatientId != null) {
                setState(() => _selectedPatientId = null);
              } else {
                context.go('/');
              }
            },
            tooltip: 'Back',
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, -0.6),
              radius: 1.5,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.12),
                GozAITheme.obsidian,
                const Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _selectedPatientId == null
                ? _buildPatientRoster(context)
                : _buildPatientTelemetry(context, _selectedPatientId!),
          ),
        ),
      ),
    );
  }

  /// The primary view: a multi-patient roster
  Widget _buildPatientRoster(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(top: 8, right: 16),
                decoration: BoxDecoration(
                  color: GozAITheme.malachite,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: GozAITheme.malachite.withValues(alpha: 0.8), blurRadius: 16),
                  ],
                ),
              ).animate().scaleY(begin: 0, duration: 800.ms, curve: Curves.easeOutCirc),
              Expanded(
                child: Text(
                  'Active\nPatients.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(height: 1.0),
                ).animate().fade(duration: 600.ms).slideX(begin: -0.1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Select a patient to view detailed AI telemetry',
            style: Theme.of(context).textTheme.bodyMedium,
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 48),

          // For the sake of the hackathon, we fetch all users with role 'Patient'
          // In a strict prod environment, we would query: users -> where arrayContains assigned_patients
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Patient')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: GozAITheme.malachite));
              }
              if (snapshot.hasError) {
                return const Text('Error loading patients', style: TextStyle(color: GozAITheme.hazardAlert));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                // Return a mock fallback if no patients in DB yet
                return _buildMockRosterCard(context, 'demo_patient_001', 'Demo Patient', 'Stable');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown Patient';
                  final pUid = docs[index].id;
                  final status = data['status'] ?? 'Monitoring Active';
                  return _buildMockRosterCard(context, pUid, name, status)
                      .animate().fade(delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.1);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMockRosterCard(BuildContext context, String pUid, String name, String status) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPatientId = pUid),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: GozAITheme.obsidian,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GozAITheme.proBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: GozAITheme.malachite.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: GozAITheme.malachite),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: GozAITheme.malachite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: GozAITheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  /// The drill-down view: specific patient telemetry
  Widget _buildPatientTelemetry(BuildContext context, String patientId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(top: 8, right: 16),
                decoration: BoxDecoration(
                  color: GozAITheme.malachite,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: GozAITheme.malachite.withValues(alpha: 0.8), blurRadius: 16),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  'Clinical\nInsights.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(height: 1.0),
                ),
              ),
            ],
          ).animate().fade().slideX(begin: -0.1),
          const SizedBox(height: 12),
          Text(
            'Viewing telemetry for: \$patientId',
            style: Theme.of(context).textTheme.bodyMedium,
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 48),

          // Key Metrics Row
          Row(
            children: [
              Expanded(
                child: _ClinicalDataCard(
                  title: 'Avg Session',
                  value: '42m',
                  trend: '+12% this w/k',
                  isPositiveTrend: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ClinicalDataCard(
                  title: 'OCR Assists',
                  value: '84',
                  trend: '+21% this w/k',
                  isPositiveTrend: true,
                ),
              ),
            ],
          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 48),

          // Section Header
          Row(
            children: [
              Icon(Icons.biotech_rounded, size: 18, color: GozAITheme.malachite),
              const SizedBox(width: 10),
              Text(
                'FLAGGED CLINICAL EVENTS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GozAITheme.malachite),
              ),
            ],
          ).animate().fade(delay: 400.ms),
          const SizedBox(height: 20),
          _buildFlaggedEventsTable(context, patientId).animate().fade(delay: 500.ms).scale(begin: const Offset(0.98, 0.98)),
        ],
      ),
    );
  }

  Widget _buildFlaggedEventsTable(BuildContext context, String patientId) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GozAITheme.proBorder, width: 1.5),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('patients')
                .doc(patientId) // Use the dynamic ID!
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
                    child: Text('Error loading telemetry: \${snapshot.error}',
                        style: const TextStyle(color: GozAITheme.hazardAlert)),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.monitor_heart_rounded, size: 48, color: GozAITheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No recent clinical events logged.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    GozAITheme.malachite.withValues(alpha: 0.04),
                  ),
                  headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: GozAITheme.malachite,
                    fontSize: 11,
                  ),
                  dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GozAITheme.textPrimary,
                  ),
                  dividerThickness: 1,
                  dataRowMaxHeight: 80,
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
                      context,
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

  DataRow _buildRow(BuildContext context, String time, String type, String note, String severity) {
    final Color severityColor;
    switch (severity) {
      case 'High':
      case 'critical':
        severityColor = GozAITheme.hazardAlert;
        break;
      case 'Medium':
      case 'mild':
        severityColor = const Color(0xFFFFAA00);
        break;
      default:
        severityColor = GozAITheme.malachite;
        break;
    }
    return DataRow(
      cells: [
        DataCell(Text(time, style: const TextStyle(color: GozAITheme.textSecondary, fontFeatures: [FontFeature.tabularFigures()]))),
        DataCell(Text(
          type.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(color: severityColor, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        )),
        DataCell(Container(
          width: 260,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(note, style: const TextStyle(color: GozAITheme.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        )),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: severityColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Text(
              severity.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 10,
                color: severityColor,
              ),
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GozAITheme.malachite.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GozAITheme.proBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: GozAITheme.obsidian.withValues(alpha: 0.4),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: GozAITheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 36,
                  color: GozAITheme.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isPositiveTrend ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 16,
                    color: isPositiveTrend ? GozAITheme.malachite : GozAITheme.hazardAlert,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trend,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: isPositiveTrend ? GozAITheme.malachite : GozAITheme.hazardAlert,
                        fontWeight: FontWeight.w700,
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
