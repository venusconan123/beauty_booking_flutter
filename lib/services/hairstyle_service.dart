import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

import '../models/hairstyle.dart';

class HairstyleService {
  HairstyleService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('hairstyles');

  Stream<List<Hairstyle>> watchHairstyles({bool activeOnly = false}) {
    return _collection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(Hairstyle.fromDocument)
          .where((item) => !activeOnly || item.isActive)
          .toList();
      items.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  Future<void> create({
    required String name,
    required String description,
    required Uint8List imageBytes,
    required String fileName,
    bool isActive = true,
  }) async {
    final uploaded = await _upload(imageBytes, fileName);
    await _collection.add({
      'name': name.trim(),
      'description': description.trim(),
      'imageUrl': uploaded.$1,
      'storagePath': uploaded.$2,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update({
    required Hairstyle hairstyle,
    required String name,
    required String description,
    required bool isActive,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    String imageUrl = hairstyle.imageUrl;
    String storagePath = hairstyle.storagePath;

    if (imageBytes != null && fileName != null) {
      final uploaded = await _upload(imageBytes, fileName);
      imageUrl = uploaded.$1;
      storagePath = uploaded.$2;
    }

    await _collection.doc(hairstyle.id).update({
      'name': name.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (imageBytes != null && hairstyle.storagePath.isNotEmpty) {
      await _deleteStorageObject(hairstyle.storagePath);
    }
  }

  Future<void> delete(Hairstyle hairstyle) async {
    await _collection.doc(hairstyle.id).delete();
    if (hairstyle.storagePath.isNotEmpty) {
      await _deleteStorageObject(hairstyle.storagePath);
    }
  }

  Future<void> seedDefaults() async {
    for (final hairstyle in defaultHairstyles) {
      final existing = await _collection
          .where('name', isEqualTo: hairstyle.name)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final data = await rootBundle.load(hairstyle.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final fileName = hairstyle.assetPath.split('/').last;
      await create(
        name: hairstyle.name,
        description: hairstyle.description,
        imageBytes: bytes,
        fileName: fileName,
      );
    }
  }

  Future<(String, String)> _upload(
    Uint8List bytes,
    String originalName,
  ) async {
    final safeName = originalName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    final path =
        'hairstyles/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(originalName)),
    );
    return (await snapshot.ref.getDownloadURL(), path);
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _deleteStorageObject(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
