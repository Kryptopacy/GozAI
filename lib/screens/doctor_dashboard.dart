import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GozAITheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('Clinical Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
          tooltip: 'Back to Home',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Patient Analytics',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Updated just now',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              
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
                  SizedBox(width: 16),
                  Expanded(
                    child: _ClinicalDataCard(
                      title: 'Interaction Count',
                      value: '143',
                      trend: '+5% vs last week',
                      isPositiveTrend: true,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _ClinicalDataCard(
                      title: 'Light Warnings',
                      value: '2',
                      trend: '-3 vs last week',
                      isPositiveTrend: true,
                    ),
                  ),
                  SizedBox(width: 16),
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

              // Detailed Clinical Logging Table
              Text(
                'Recent Flagged Events',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildFlaggedEventsTable(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlaggedEventsTable(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: DataTable(
        headingTextStyle: const TextStyle(
          color: GozAITheme.textSecondary,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        dataTextStyle: Theme.of(context).textTheme.labelLarge,
        dividerThickness: 1,
        columns: const [
          DataColumn(label: Text('DATE / TIME')),
          DataColumn(label: Text('EVENT TYPE')),
          DataColumn(label: Text('CLINICAL NOTE')),
          DataColumn(label: Text('SEVERITY')),
        ],
        rows: [
          _buildRow('2026-02-23 14:30', 'Light Sensitivity', 'Patient stepped into direct, harsh lighting > 10,000 lux. Navigated away after 4s.', 'Low'),
          _buildRow('2026-02-21 09:15', 'Prolonged Reading', 'Continuous OCR usage for > 45 minutes. Suggested eye rest interval.', 'Medium'),
          _buildRow('2026-02-19 18:45', 'Voice Assistance', 'Requested navigation help in unfamiliar kitchen environment.', 'Low'),
        ],
      ),
    );
  }

  DataRow _buildRow(String time, String type, String note, String severity) {
    return DataRow(
      cells: [
        DataCell(Text(time)),
        DataCell(Text(type, style: const TextStyle(color: GozAITheme.primaryBlue))),
        DataCell(Text(note, style: const TextStyle(color: GozAITheme.textSecondary, fontSize: 14))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: severity == 'Medium' ? Colors.amber.withValues(alpha: 0.2) : GozAITheme.borderSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 12,
                color: severity == 'Medium' ? Colors.amber : GozAITheme.textSecondary,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GozAITheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GozAITheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GozAITheme.textSecondary,
              letterSpacing: 0.5,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: GozAITheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositiveTrend ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isPositiveTrend ? GozAITheme.success : GozAITheme.hazardAlert,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 12,
                  color: isPositiveTrend ? GozAITheme.success : GozAITheme.hazardAlert,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
