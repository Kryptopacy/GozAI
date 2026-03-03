import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// Clinical Telemetry Service logs actionable medical and safety data
/// designed specifically for Optometrists (O&M, ADL tracking) and Caregivers.
class ClinicalTelemetryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // The patient ID for demo purposes
  final String patientId = 'demo_patient_001';

  // --- Optometrist Metrics (Functional Vision) ---
  
  /// Logs when the user rapidly turns away from high lighting (Photophobia / Glare marker).
  Future<void> logPhotophobiaEvent(double peakLux) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'glare_aversion',
        'timestamp': FieldValue.serverTimestamp(),
        'lux': peakLux,
        'severity': peakLux > 10000 ? 'High' : 'Medium',
        'note': 'Rapid camera movement detected in a high-lux environment.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log photophobia event: $e');
    }
  }

  /// Logs the ambient light required to successfully read text (Contrast Sensitivity marker).
  Future<void> logOcrAssist(double ambientLux, int characterCount) async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'ocr_assist',
        'timestamp': FieldValue.serverTimestamp(),
        'ambientLux': ambientLux,
        'characterCount': characterCount,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log OCR assist: $e');
    }
  }

  /// Logs reading stamina (time spent in Reading mode).
  Future<void> logReadingStamina(Duration duration) async {
    if (!AppConfig.isConfigured || duration.inSeconds < 10) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('functional_metrics').add({
        'type': 'reading_session',
        'timestamp': FieldValue.serverTimestamp(),
        'durationSeconds': duration.inSeconds,
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log reading stamina: $e');
    }
  }

  // --- Caregiver Metrics (Safety & Independence) ---

  /// Logs physical hazards detected by Gemini.
  Future<void> logHazardDetected(String pattern) async {
    if (!AppConfig.isConfigured || pattern != 'hazard') return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'hazard',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'High',
        'note': 'Agent detected and triggered a hazard proximity warning.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log hazard: $e');
    }
  }

  /// Logs evidence of spatial disorientation (Wandering).
  Future<void> logSpatialDisorientation() async {
    if (!AppConfig.isConfigured) return;
    try {
      await _firestore.collection('patients').doc(patientId).collection('clinical_events').add({
        'type': 'wandering',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'Medium',
        'note': 'Repeated rapid mode-switching indicating potential spatial disorientation.',
      });
    } catch (e) {
      debugPrint('Telemetry: Failed to log wandering: $e');
    }
  }
}
