import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../person.dart';

class PersonStorage {
  PersonStorage._();

  static final PersonStorage instance =
      PersonStorage._();

  static const String _boxName = 'faceshare_people';

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
  // ADD PERSON
  // ============================================================

  Future<void> addPerson(Person person) async {
    await initialize();

    final data = {
      'id': person.id,
      'name': person.name,
      'imagePath': person.imagePath,
      'faceEmbedding': person.faceEmbedding,

      // FaceShare information
      'faceShareUserId': person.faceShareUserId,
      'sharingEnabled': person.sharingEnabled,
    };

    await _box.put(
      person.id,
      jsonEncode(data),
    );
  }

  // ============================================================
  // GET ALL PEOPLE
  // ============================================================

  List<Person> getPeople() {
    if (!_initialized) {
      throw StateError(
        'PersonStorage has not been initialized.',
      );
    }

    final List<Person> people = [];

    for (final value in _box.values) {
      if (value is! String) continue;

      try {
        final Map<String, dynamic> data =
            jsonDecode(value);

        final embedding =
            (data['faceEmbedding'] as List?)
                    ?.map(
                      (e) => (e as num).toDouble(),
                    )
                    .toList() ??
                <double>[];

        final person = Person(
          id: data['id'].toString(),

          name: data['name'].toString(),

          imagePath:
              data['imagePath'].toString(),

          faceEmbedding: embedding,

          // FaceShare fields
          faceShareUserId:
              data['faceShareUserId']?.toString() ??
                  'FS_${data['id']}',

          sharingEnabled:
              data['sharingEnabled'] as bool? ??
                  true,
        );

        people.add(person);
      } catch (e) {
        // Ignore corrupted records.
        continue;
      }
    }

    return people;
  }

  // ============================================================
  // GET PERSON BY ID
  // ============================================================

  Person? getPersonById(String id) {
    final people = getPeople();

    try {
      return people.firstWhere(
        (person) => person.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET PERSON BY FACESHARE ID
  // ============================================================

  Person? getPersonByFaceShareId(
    String faceShareUserId,
  ) {
    final people = getPeople();

    try {
      return people.firstWhere(
        (person) =>
            person.faceShareUserId ==
            faceShareUserId,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // UPDATE PERSON
  // ============================================================

  Future<void> updatePerson(Person person) async {
    await initialize();

    final data = {
      'id': person.id,
      'name': person.name,
      'imagePath': person.imagePath,
      'faceEmbedding': person.faceEmbedding,
      'faceShareUserId':
          person.faceShareUserId,
      'sharingEnabled':
          person.sharingEnabled,
    };

    await _box.put(
      person.id,
      jsonEncode(data),
    );
  }

  // ============================================================
  // DELETE PERSON
  // ============================================================

  Future<void> deletePerson(
    String id,
  ) async {
    await initialize();

    await _box.delete(id);
  }

  // ============================================================
  // CLEAR ALL PEOPLE
  // ============================================================

  Future<void> clearAll() async {
    await initialize();

    await _box.clear();
  }
}