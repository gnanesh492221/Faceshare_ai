import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../sharing_history.dart';

class SharingStorage {
  SharingStorage._();

  static final SharingStorage instance =
      SharingStorage._();

  static const String _boxName =
      'faceshare_sharing_history';

  late Box _box;

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
  // ADD HISTORY
  // ============================================================

  Future<void> addHistory(
    SharingHistory history,
  ) async {
    await initialize();

    final Map<String, dynamic> data = {
      'id': history.id,
      'imagePath': history.imagePath,
      'sharedWith': history.sharedWith,
      'createdAt':
          history.createdAt.toIso8601String(),
    };

    await _box.put(
      history.id,
      jsonEncode(data),
    );
  }

  // ============================================================
  // GET ALL HISTORY
  // ============================================================

  List<SharingHistory> getHistory() {
    if (!_initialized) {
      throw StateError(
        'SharingStorage has not been initialized.',
      );
    }

    final List<SharingHistory> history = [];

    for (final value in _box.values) {
      if (value is! String) {
        continue;
      }

      try {
        final Map<String, dynamic> data =
            jsonDecode(value);

        final dynamic rawPeople =
            data['sharedWith'];

        final List<String> people = [];

        if (rawPeople is List) {
          for (final item in rawPeople) {
            final String name =
                item.toString().trim();

            if (name.isNotEmpty &&
                !people.contains(name)) {
              people.add(name);
            }
          }
        }

        history.add(
          SharingHistory(
            id: data['id'].toString(),
            imagePath:
                data['imagePath'].toString(),
            sharedWith: people,
            createdAt: DateTime.parse(
              data['createdAt'].toString(),
            ),
          ),
        );
      } catch (_) {
        // Ignore corrupted records.
      }
    }

    // Newest first.
    history.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return history;
  }

  // ============================================================
  // GET SINGLE HISTORY
  // ============================================================

  SharingHistory? getHistoryById(
    String id,
  ) {
    if (!_initialized) {
      throw StateError(
        'SharingStorage has not been initialized.',
      );
    }

    final value = _box.get(id);

    if (value is! String) {
      return null;
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(value);

      final dynamic rawPeople =
          data['sharedWith'];

      final List<String> people = [];

      if (rawPeople is List) {
        for (final item in rawPeople) {
          final String name =
              item.toString().trim();

          if (name.isNotEmpty &&
              !people.contains(name)) {
            people.add(name);
          }
        }
      }

      return SharingHistory(
        id: data['id'].toString(),
        imagePath:
            data['imagePath'].toString(),
        sharedWith: people,
        createdAt: DateTime.parse(
          data['createdAt'].toString(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DELETE SINGLE HISTORY
  // ============================================================

  Future<void> deleteHistory(
    String id,
  ) async {
    await initialize();

    await _box.delete(id);
  }

  // ============================================================
  // CLEAR ALL HISTORY
  // ============================================================

  Future<void> clearHistory() async {
    await initialize();

    await _box.clear();
  }

  // ============================================================
  // TOTAL HISTORY COUNT
  // ============================================================

  int get count {
    if (!_initialized) {
      throw StateError(
        'SharingStorage has not been initialized.',
      );
    }

    return _box.length;
  }
}