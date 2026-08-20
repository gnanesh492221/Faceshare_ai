import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../received_photo.dart';

class ReceivedStorage {
  ReceivedStorage._();

  static final ReceivedStorage instance =
      ReceivedStorage._();

  static const String _boxName =
      'faceshare_received_photos';

  Box? _box;
  bool _initialized = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized && _box != null) {
      return;
    }

    await Hive.initFlutter();

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }

    _initialized = true;
  }

  // ============================================================
  // ADD PHOTO
  // ============================================================

  Future<void> addPhoto(
    ReceivedPhoto photo,
  ) async {
    await initialize();

    final Map<String, dynamic> data = {
      'id': photo.id,
      'imagePath': photo.imagePath,
      'senderName': photo.senderName,
      'senderUid': photo.senderUid,
      'receivedAt': photo.receivedAt.toIso8601String(),
      'isRead': photo.isRead,
    };

    await _box!.put(
      photo.id,
      jsonEncode(data),
    );
  }

  // ============================================================
  // GET ALL PHOTOS
  // ============================================================

  List<ReceivedPhoto> getPhotos() {
    if (!_initialized || _box == null) {
      throw StateError(
        'ReceivedStorage has not been initialized.',
      );
    }

    final List<ReceivedPhoto> photos = [];

    for (final dynamic value in _box!.values) {
      if (value is! String) {
        continue;
      }

      try {
        final Map<String, dynamic> data =
            jsonDecode(value);

        final String id =
            data['id']?.toString() ?? '';

        final String imagePath =
            data['imagePath']?.toString() ?? '';

        final String senderName =
            data['senderName']?.toString() ??
                'Unknown sender';

        final String senderUid =
            data['senderUid']?.toString() ?? '';

        final String receivedAt =
            data['receivedAt']?.toString() ?? '';

        final bool isRead =
            data['isRead'] == true;

        if (id.isEmpty ||
            imagePath.isEmpty ||
            receivedAt.isEmpty) {
          continue;
        }

        photos.add(
          ReceivedPhoto(
            id: id,
            imagePath: imagePath,
            senderName: senderName,
            senderUid: senderUid,
            receivedAt: DateTime.parse(receivedAt),
            isRead: isRead,
          ),
        );
      } catch (_) {
        // Ignore corrupted records.
      }
    }

    photos.sort(
      (a, b) => b.receivedAt.compareTo(a.receivedAt),
    );

    return photos;
  }

  // ============================================================
  // GET ONE PHOTO
  // ============================================================

  ReceivedPhoto? getPhoto(
    String id,
  ) {
    if (!_initialized || _box == null) {
      throw StateError(
        'ReceivedStorage has not been initialized.',
      );
    }

    final dynamic value = _box!.get(id);

    if (value is! String) {
      return null;
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(value);

      return ReceivedPhoto(
        id: data['id']?.toString() ?? id,
        imagePath:
            data['imagePath']?.toString() ?? '',
        senderName:
            data['senderName']?.toString() ??
                'Unknown sender',
        senderUid:
            data['senderUid']?.toString() ?? '',
        receivedAt: DateTime.parse(
          data['receivedAt'].toString(),
        ),
        isRead: data['isRead'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // MARK AS READ
  // ============================================================

  Future<void> markAsRead(
    String id,
  ) async {
    await initialize();

    final ReceivedPhoto? photo =
        getPhoto(id);

    if (photo == null) {
      return;
    }

    await addPhoto(
      photo.copyWith(
        isRead: true,
      ),
    );
  }

  // ============================================================
  // UNREAD COUNT
  // ============================================================

  int get unreadCount {
    if (!_initialized || _box == null) {
      throw StateError(
        'ReceivedStorage has not been initialized.',
      );
    }

    return getPhotos()
        .where((photo) => !photo.isRead)
        .length;
  }

  // ============================================================
  // EXISTS
  // ============================================================

  bool contains(
    String id,
  ) {
    if (!_initialized || _box == null) {
      throw StateError(
        'ReceivedStorage has not been initialized.',
      );
    }

    return _box!.containsKey(id);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deletePhoto(
    String id,
  ) async {
    await initialize();

    final ReceivedPhoto? photo =
        getPhoto(id);

    if (photo != null) {
      try {
        final File file =
            File(photo.imagePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await _box!.delete(id);
  }

  // ============================================================
  // DELETE ALL
  // ============================================================

  Future<void> clearAll() async {
    await initialize();

    final List<ReceivedPhoto> photos =
        getPhotos();

    for (final ReceivedPhoto photo in photos) {
      try {
        final File file =
            File(photo.imagePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await _box!.clear();
  }

  // ============================================================
  // COUNT
  // ============================================================

  int get count {
    if (!_initialized || _box == null) {
      throw StateError(
        'ReceivedStorage has not been initialized.',
      );
    }

    return _box!.length;
  }

  // ============================================================
  // STORAGE DIRECTORY
  // ============================================================

  Future<Directory> getStorageDirectory() async {
    final Directory directory =
        await getApplicationDocumentsDirectory();

    final Directory receivedDirectory =
        Directory(
      '${directory.path}/faceshare_received',
    );

    if (!await receivedDirectory.exists()) {
      await receivedDirectory.create(
        recursive: true,
      );
    }

    return receivedDirectory;
  }
}