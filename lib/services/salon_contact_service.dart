import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/sample_salons.dart';
import '../models/salon.dart';

class SalonContactService {
  static const String _settingsDocumentId = 'salon_contacts';

  final FirebaseFirestore _firestore;

  SalonContactService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _settingsReference =>
      _firestore.collection('app_settings').doc(_settingsDocumentId);

  Stream<Map<String, String>> watchHotlines() {
    return _settingsReference.snapshots().map((snapshot) {
      return _readHotlines(snapshot.data());
    });
  }

  Stream<String> watchHotline(Salon salon) {
    return watchHotlines().map((hotlines) {
      return hotlines[salon.id] ?? salon.hotline;
    });
  }

  Future<String> getHotline(Salon salon) async {
    try {
      final hotlines = await getHotlines();
      return hotlines[salon.id] ?? salon.hotline;
    } on FirebaseException {
      return salon.hotline;
    }
  }

  Future<Map<String, String>> getHotlines() async {
    final snapshot = await _settingsReference.get();
    return _readHotlines(snapshot.data());
  }

  Future<void> saveHotlines(Map<String, String> hotlines) async {
    await _settingsReference.set({
      'hotlines': hotlines,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, String> defaults() {
    return {for (final salon in sampleSalons) salon.id: salon.hotline};
  }

  Map<String, String> _readHotlines(Map<String, dynamic>? data) {
    final values = defaults();
    final stored = data?['hotlines'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          values[entry.key.toString()] = value;
        }
      }
    }
    return values;
  }
}
