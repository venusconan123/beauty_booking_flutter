import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/sample_barbers.dart';
import '../models/barber.dart';

class BarberService {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('employees');

  Stream<List<Barber>> watchBySalon(String salonId) {
    return _collection.snapshots().map(
      (snapshot) {
        final barbers = snapshot.docs
            .where((document) => document.id != '_catalog')
            .map((document) => Barber.fromDocument(document.id, document.data()))
            .where((barber) => barber.salonId == salonId && barber.isActive)
            .toList();
        if (snapshot.docs.isEmpty) {
          return getBarbersBySalonId(salonId).map(_profiled).toList();
        }
        barbers.sort((first, second) => second.rating.compareTo(first.rating));
        return barbers;
      },
    );
  }

  Stream<List<Barber>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final barbers = snapshot.docs
          .where((document) => document.id != '_catalog')
          .map((document) => Barber.fromDocument(document.id, document.data()))
          .toList();
      if (snapshot.docs.isEmpty) return sampleBarbers.map(_profiled).toList();
      barbers.sort((first, second) {
        final salonComparison = first.salonId.compareTo(second.salonId);
        return salonComparison != 0
            ? salonComparison
            : first.name.compareTo(second.name);
      });
      return barbers;
    });
  }

  Future<List<Barber>> getBySalon(String salonId) async {
    final snapshot = await _collection.get();
    if (snapshot.docs.isEmpty) {
      return getBarbersBySalonId(salonId).map(_profiled).toList();
    }
    final barbers = snapshot.docs
        .where((document) => document.id != '_catalog')
        .map((document) => Barber.fromDocument(document.id, document.data()))
        .where((barber) => barber.salonId == salonId && barber.isActive)
        .toList();
    barbers.sort((first, second) => second.rating.compareTo(first.rating));
    return barbers;
  }

  Future<void> ensureDefaults() async {
    final marker = await _collection.doc('_catalog').get();
    if (marker.data()?['defaultsInitialized'] == true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final barber in sampleBarbers) {
      final profile = _profiled(barber);
      batch.set(_collection.doc(barber.id), {
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_collection.doc('_catalog'), {
      'type': 'configuration',
      'defaultsInitialized': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> create(Barber barber) async {
    await _collection.add({
      ...barber.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(Barber barber) async {
    await _collection.doc(barber.id).update({
      ...barber.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _collection.doc(id).delete();

  Barber _profiled(Barber barber) {
    final number = int.tryParse(barber.id.split('_').last) ?? 1;
    const skillSets = <List<String>>[
      ['Cắt tóc', 'Fade', 'Tạo kiểu'],
      ['Uốn tóc', 'Korean Layer', 'Tư vấn'],
      ['Nhuộm tóc', 'Side Part', 'Tạo kiểu'],
      ['Undercut', 'Cắt cổ điển', 'Chăm sóc'],
      ['Textured Crop', 'Uốn tóc', 'Fade'],
    ];
    return Barber(
      id: barber.id,
      salonId: barber.salonId,
      name: barber.name,
      experienceYears: barber.experienceYears,
      rating: barber.rating,
      imageUrl: barber.imageUrl,
      age: 22 + (number % 9),
      gender: 'Nam',
      skills: skillSets[(number - 1) % skillSets.length],
      reviewCount: 68 + number * 17,
      bio: 'Chuyên gia tóc nam với ${barber.experienceYears} năm kinh nghiệm, '
          'tư vấn kiểu tóc phù hợp khuôn mặt và phong cách cá nhân.',
      isActive: true,
    );
  }
}
