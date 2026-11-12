import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/sample_barbers.dart';
import '../models/barber.dart';
import 'scheduling_service.dart';
import 'barber_ratings_stream.dart';

class BarberService {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('employees');

  Stream<List<Barber>> watchBySalon(String salonId) {
    return restartableBarberStream(
      () => _withRatings(_scheduledBarbers(salonId)),
    );
  }

  Stream<List<Barber>> _scheduledBarbers(String salonId) async* {
    final result = await SchedulingService().call('listBookableStaff', {
      'salonId': salonId,
    });
    final ids = (result['employees'] as List)
        .map((row) => (row as Map)['id'] as String)
        .toSet();
    if (ids.isEmpty) {
      yield [];
      return;
    }
    yield* _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .where(
            (doc) => ids.contains(doc.id) && doc.data()['isActive'] != false,
          )
          .map((doc) => Barber.fromDocument(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<Map<String, ({double average, int count})>> _ratings(
    List<String> ids,
  ) async {
    final ratings = <String, ({double average, int count})>{};
    for (var offset = 0; offset < ids.length; offset += 100) {
      final result = await SchedulingService().call('getBarberRatings', {
        'employeeIds': ids.skip(offset).take(100).toList(),
      });
      for (final row in result['ratings'] as List) {
        final data = row as Map;
        ratings[data['employeeId'] as String] = (
          average: (data['rating'] as num).toDouble(),
          count: (data['reviewCount'] as num).toInt(),
        );
      }
    }
    return ratings;
  }

  Stream<List<Barber>> _withRatings(Stream<List<Barber>> profiles) =>
      watchBarberRatings(
        profiles: profiles,
        reviewChanges: FirebaseFirestore.instance
            .collection('reviews')
            .snapshots(),
        load: _ratings,
      );

  Stream<List<Barber>> watchAll() {
    return restartableBarberStream(
      () => _withRatings(
        _collection.snapshots().map((snapshot) {
          final barbers = snapshot.docs
              .where((document) => document.id != '_catalog')
              .map(
                (document) => Barber.fromDocument(document.id, document.data()),
              )
              .toList();
          barbers.sort((first, second) {
            final salonComparison = first.salonId.compareTo(second.salonId);
            return salonComparison != 0
                ? salonComparison
                : first.name.compareTo(second.name);
          });
          return barbers;
        }),
      ),
    );
  }

  Future<List<Barber>> getBySalon(String salonId) async {
    final snapshot = await _collection.get();
    final barbers = snapshot.docs
        .where((document) => document.id != '_catalog')
        .map((document) => Barber.fromDocument(document.id, document.data()))
        .where((barber) => barber.salonId == salonId && barber.isActive)
        .toList();
    final stats = await _ratings(barbers.map((barber) => barber.id).toList());
    final result = barbers
        .map(
          (barber) => barber.withReviewStats(
            average: stats[barber.id]!.average,
            count: stats[barber.id]!.count,
          ),
        )
        .toList();
    result.sort((first, second) => second.rating.compareTo(first.rating));
    return result;
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
    // toMap contains profile fields only, never manual rating/reviewCount.
    final profile = barber.toMap();
    await _collection.doc(barber.id).update({
      ...profile,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _collection.doc(id).update({
    'isActive': false,
    'updatedAt': FieldValue.serverTimestamp(),
  });

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
      rating: 0,
      imageUrl: barber.imageUrl,
      age: 22 + (number % 9),
      gender: 'Nam',
      skills: skillSets[(number - 1) % skillSets.length],
      reviewCount: 0,
      bio:
          'Chuyên gia tóc nam với ${barber.experienceYears} năm kinh nghiệm, '
          'tư vấn kiểu tóc phù hợp khuôn mặt và phong cách cá nhân.',
      isActive: true,
    );
  }
}
