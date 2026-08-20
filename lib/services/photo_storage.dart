import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../photo.dart';

class PhotoStorage {
  PhotoStorage._();

  static final PhotoStorage instance = PhotoStorage._();

  static const String _boxName = 'faceshare_photos';

  Box? _box;
  bool _initialized = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();

    _box = await Hive.openBox(_boxName);

    _initialized = true;
  }

  // ============================================================
  // ADD PHOTO
  // ============================================================

  Future<void> addPhoto(FacePhoto photo) async {
    await initialize();

    final data = <String, dynamic>{
      'id': photo.id,
      'imagePath': photo.imagePath,
      'recognizedPeople': photo.recognizedPeople,
      'createdAt': photo.createdAt.toIso8601String(),
    };

    await _box!.put(
      photo.id,
      jsonEncode(data),
    );
  }

  // ============================================================
  // GET ALL PHOTOS
  // ============================================================

  List<FacePhoto> getPhotos() {
    if (!_initialized || _box == null) {
      throw StateError(
        'PhotoStorage has not been initialized.',
      );
    }

    final List<FacePhoto> photos = [];

    for (final value in _box!.values) {
      if (value is! String) {
        continue;
      }

      try {
        final decoded = jsonDecode(value);

        if (decoded is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(decoded);

        final recognizedPeople =
            (data['recognizedPeople'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];

        final createdAtString =
            data['createdAt']?.toString();

        if (createdAtString == null) {
          continue;
        }

        photos.add(
          FacePhoto(
            id: data['id']?.toString() ?? '',
            imagePath:
                data['imagePath']?.toString() ?? '',
            recognizedPeople: recognizedPeople,
            createdAt:
                DateTime.parse(createdAtString),
          ),
        );
      } catch (e) {
        // Ignore corrupted records.
        continue;
      }
    }

    return photos;
  }

  // ============================================================
  // GET PHOTOS FOR PERSON
  // ============================================================

  List<FacePhoto> getPhotosForPerson(
    String personName,
  ) {
    return getPhotos()
        .where(
          (photo) =>
              photo.recognizedPeople.contains(
                personName,
              ),
        )
        .toList();
  }

  // ============================================================
  // DELETE PHOTO
  // ============================================================

  Future<void> deletePhoto(String id) async {
    await initialize();

    await _box!.delete(id);
  }

  // ============================================================
  // CLEAR ALL PHOTOS
  // ============================================================

  Future<void> clearAll() async {
    await initialize();

    await _box!.clear();
  }
}