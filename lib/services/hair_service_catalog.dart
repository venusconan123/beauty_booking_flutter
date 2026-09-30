import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/sample_salons.dart';
import '../models/hair_service.dart';

class HairServiceCatalog {
  HairServiceCatalog({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('services');

  Stream<List<HairService>> watchActive() {
    return watchAll().map(
      (items) => items
          .where((item) => item.isActive)
          .map((item) => item.service)
          .where(
            (service) =>
                service.name.isNotEmpty &&
                service.price >= 0 &&
                service.durationMinutes > 0,
          )
          .toList(),
    );
  }

  Stream<List<ServiceAdminItem>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final remote = {
        for (final doc in snapshot.docs)
          doc.id: ServiceAdminItem(
            service: HairService.fromMap(doc.id, doc.data()),
            isActive: doc.data()['isActive'] as bool? ?? true,
            order: (doc.data()['order'] as num?)?.toInt() ?? 999,
          ),
      };
      final result = <ServiceAdminItem>[];
      for (var index = 0; index < commonServices.length; index++) {
        final fallback = commonServices[index];
        result.add(
          remote.remove(fallback.id) ??
              ServiceAdminItem(
                service: fallback,
                isActive: true,
                order: index,
              ),
        );
      }
      result.addAll(remote.values);
      result.sort((a, b) => a.order.compareTo(b.order));
      return result;
    });
  }

  Future<void> save({
    required HairService service,
    required bool isActive,
    required int order,
  }) {
    return _collection.doc(service.id).set({
      ...service.toMap(),
      'isActive': isActive,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> create(HairService service) {
    return _collection.doc(service.id).set({
      ...service.toMap(),
      'isActive': true,
      'order': 999,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String serviceId) async {
    final fallbackIndex = commonServices.indexWhere(
      (service) => service.id == serviceId,
    );
    if (fallbackIndex >= 0) {
      await save(
        service: commonServices[fallbackIndex],
        isActive: false,
        order: fallbackIndex,
      );
      return;
    }
    await _collection.doc(serviceId).delete();
  }
}

class ServiceAdminItem {
  const ServiceAdminItem({
    required this.service,
    required this.isActive,
    required this.order,
  });

  final HairService service;
  final bool isActive;
  final int order;
}
