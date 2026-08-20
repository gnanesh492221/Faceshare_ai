import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

import '../person.dart';
import 'person_storage.dart';

class FaceRecognitionService {
  FaceRecognitionService._();

  static final FaceRecognitionService instance =
      FaceRecognitionService._();

  final FaceDetector _detector = FaceDetector();

  bool _initialized = false;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Similarity threshold.
  ///
  /// Higher = stricter matching.
  /// Lower = more tolerant matching.
  static const double defaultThreshold = 0.60;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) return;

    await _detector.initialize(
      model: FaceDetectionModel.backCamera,
    );

    _initialized = true;
  }

  // ============================================================
  // DETECT FACES
  // ============================================================

  Future<List<Face>> detectFaces(
    String imagePath,
  ) async {
    await initialize();

    final File file = File(imagePath);

    if (!await file.exists()) {
      throw Exception(
        'Image file does not exist: $imagePath',
      );
    }

    final Uint8List bytes =
        await file.readAsBytes();

    // IMPORTANT:
    // Full mode gives better landmark information
    // for face alignment and embedding generation.
    final List<Face> faces =
        await _detector.detectFacesFromBytes(
      bytes,
      mode: FaceDetectionMode.full,
    );

    debugPrint(
      'Face detection: ${faces.length} face(s)',
    );

    return faces;
  }

  // ============================================================
  // CREATE FACE EMBEDDING
  // ============================================================

  Future<Float32List> createEmbedding(
    Face face,
    String imagePath,
  ) async {
    await initialize();

    final File file = File(imagePath);

    if (!await file.exists()) {
      throw Exception(
        'Image file does not exist: $imagePath',
      );
    }

    final Uint8List bytes =
        await file.readAsBytes();

    final embedding =
        await _detector.getFaceEmbedding(
      face,
      bytes,
    );

    final result =
        Float32List.fromList(embedding);

    debugPrint(
      'Created face embedding: '
      '${result.length} values',
    );

    return result;
  }

  // ============================================================
  // COMPARE EMBEDDINGS
  // ============================================================

  double compare(
    List<double> first,
    List<double> second,
  ) {
    if (first.isEmpty || second.isEmpty) {
      return 0.0;
    }

    final Float32List firstEmbedding =
        Float32List.fromList(first);

    final Float32List secondEmbedding =
        Float32List.fromList(second);

    final double score =
        FaceDetector.compareFaces(
      firstEmbedding,
      secondEmbedding,
    );

    return score;
  }

  // ============================================================
  // COMPARE FLOAT32 EMBEDDINGS
  // ============================================================

  double compareEmbeddings(
    Float32List first,
    Float32List second,
  ) {
    if (first.isEmpty || second.isEmpty) {
      return 0.0;
    }

    return FaceDetector.compareFaces(
      first,
      second,
    );
  }

  // ============================================================
  // FIND MATCHING PEOPLE
  // ============================================================

  Future<List<Person>> findMatchingPeople(
    String imagePath, {
    double threshold = defaultThreshold,
  }) async {
    final List<FaceMatchResult> matches =
        await findFaceMatches(
      imagePath,
      threshold: threshold,
    );

    return matches
        .where(
          (match) => match.isRecognized,
        )
        .map(
          (match) => match.person!,
        )
        .toList();
  }

  // ============================================================
  // MAIN FACE RECOGNITION
  // ============================================================

  Future<List<FaceMatchResult>> findFaceMatches(
    String imagePath, {
    double threshold = defaultThreshold,
  }) async {
    await initialize();

    final PersonStorage personStorage =
        PersonStorage.instance;

    await personStorage.initialize();

    final List<Person> registeredPeople =
        personStorage.getPeople();

    debugPrint(
      'Registered people: '
      '${registeredPeople.length}',
    );

    if (registeredPeople.isEmpty) {
      return [];
    }

    // ----------------------------------------------------------
    // DETECT FACES
    // ----------------------------------------------------------

    final List<Face> detectedFaces =
        await detectFaces(imagePath);

    if (detectedFaces.isEmpty) {
      debugPrint('No faces found.');
      return [];
    }

    debugPrint(
      'Detected ${detectedFaces.length} face(s).',
    );

    // ----------------------------------------------------------
    // ALL POSSIBLE MATCHES
    // ----------------------------------------------------------

    final List<_CandidateMatch> candidates = [];

    // ----------------------------------------------------------
    // ANALYZE EVERY FACE
    // ----------------------------------------------------------

    for (
      int faceIndex = 0;
      faceIndex < detectedFaces.length;
      faceIndex++
    ) {
      final Face face =
          detectedFaces[faceIndex];

      debugPrint(
        '----------------------------------------',
      );

      debugPrint(
        'Analyzing face #$faceIndex',
      );

      // --------------------------------------------------------
      // CREATE EMBEDDING FOR GROUP PHOTO FACE
      // --------------------------------------------------------

      final Float32List embedding =
          await createEmbedding(
        face,
        imagePath,
      );

      // --------------------------------------------------------
      // COMPARE AGAINST EVERY REGISTERED PERSON
      // --------------------------------------------------------

      for (final Person person
          in registeredPeople) {
        // Ignore people without an embedding.
        if (person.faceEmbedding.isEmpty) {
          debugPrint(
            '${person.name}: '
            'NO REGISTERED EMBEDDING',
          );
          continue;
        }

        final Float32List registeredEmbedding =
            Float32List.fromList(
          person.faceEmbedding,
        );

        final double score =
            compareEmbeddings(
          embedding,
          registeredEmbedding,
        );

        // VERY IMPORTANT DEBUG INFORMATION
        debugPrint(
          'Face #$faceIndex → '
          '${person.name} → '
          'similarity: '
          '${score.toStringAsFixed(4)}',
        );

        candidates.add(
          _CandidateMatch(
            faceIndex: faceIndex,
            person: person,
            score: score,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // SORT BY STRONGEST MATCH
    // ----------------------------------------------------------

    candidates.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    debugPrint(
      '========================================',
    );

    debugPrint(
      'Matching threshold: '
      '${threshold.toStringAsFixed(2)}',
    );

    // ----------------------------------------------------------
    // PREVENT DUPLICATE PERSON ASSIGNMENTS
    // ----------------------------------------------------------

    final Set<String> usedPersonIds = {};
    final Set<int> usedFaceIndexes = {};

    final List<FaceMatchResult> results = [];

    // ----------------------------------------------------------
    // ASSIGN STRONGEST MATCHES
    // ----------------------------------------------------------

    for (final candidate in candidates) {
      // Below threshold = not recognized.
      if (candidate.score < threshold) {
        continue;
      }

      // Person already assigned to another face.
      if (usedPersonIds.contains(
        candidate.person.id,
      )) {
        continue;
      }

      // Face already assigned.
      if (usedFaceIndexes.contains(
        candidate.faceIndex,
      )) {
        continue;
      }

      usedPersonIds.add(
        candidate.person.id,
      );

      usedFaceIndexes.add(
        candidate.faceIndex,
      );

      debugPrint(
        'MATCH ✓ '
        'Face #${candidate.faceIndex} → '
        '${candidate.person.name} '
        '(${candidate.score.toStringAsFixed(4)})',
      );

      results.add(
        FaceMatchResult(
          person: candidate.person,
          score: candidate.score,
          faceIndex: candidate.faceIndex,
          isRecognized: true,
        ),
      );
    }

    // ----------------------------------------------------------
    // ADD UNKNOWN FACES
    // ----------------------------------------------------------

    for (
      int faceIndex = 0;
      faceIndex < detectedFaces.length;
      faceIndex++
    ) {
      final bool recognized =
          usedFaceIndexes.contains(
        faceIndex,
      );

      if (!recognized) {
        debugPrint(
          'UNKNOWN ✗ '
          'Face #$faceIndex',
        );

        results.add(
          FaceMatchResult(
            person: null,
            score: 0.0,
            faceIndex: faceIndex,
            isRecognized: false,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // SORT BY FACE INDEX
    // ----------------------------------------------------------

    results.sort(
      (a, b) => a.faceIndex.compareTo(
        b.faceIndex,
      ),
    );

    debugPrint(
      '========================================',
    );

    debugPrint(
      'Recognition complete: '
      '${results.where((r) => r.isRecognized).length} '
      'recognized / '
      '${detectedFaces.length} faces',
    );

    return results;
  }

  // ============================================================
  // COMPATIBILITY METHOD
  // ============================================================

  Future<List<FaceMatchResult>>
      findMatchingPeopleWithScores(
    String imagePath, {
    double threshold = defaultThreshold,
  }) async {
    return findFaceMatches(
      imagePath,
      threshold: threshold,
    );
  }

  // ============================================================
  // GET RECOGNIZED MATCHES
  // ============================================================

  Future<List<FaceMatchResult>>
      getRecognizedMatches(
    String imagePath, {
    double threshold = defaultThreshold,
  }) async {
    final results =
        await findFaceMatches(
      imagePath,
      threshold: threshold,
    );

    return results
        .where(
          (result) => result.isRecognized,
        )
        .toList();
  }

  // ============================================================
  // GET UNKNOWN FACE COUNT
  // ============================================================

  Future<int> getUnknownFaceCount(
    String imagePath, {
    double threshold = defaultThreshold,
  }) async {
    final results =
        await findFaceMatches(
      imagePath,
      threshold: threshold,
    );

    return results
        .where(
          (result) => !result.isRecognized,
        )
        .length;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    if (!_initialized) return;

    await _detector.dispose();

    _initialized = false;
  }
}

// ================================================================
// INTERNAL CANDIDATE
// ================================================================

class _CandidateMatch {
  final int faceIndex;
  final Person person;
  final double score;

  const _CandidateMatch({
    required this.faceIndex,
    required this.person,
    required this.score,
  });
}

// ================================================================
// FACE MATCH RESULT
// ================================================================

class FaceMatchResult {
  /// Registered person.
  ///
  /// null = unknown face.
  final Person? person;

  /// Similarity score.
  final double score;

  /// Detected face index.
  final int faceIndex;

  /// Whether the face was recognized.
  final bool isRecognized;

  const FaceMatchResult({
    required this.person,
    required this.score,
    required this.faceIndex,
    required this.isRecognized,
  });

  String get personName {
    return person?.name ?? 'Unknown person';
  }

  String? get faceShareUserId {
    return person?.faceShareUserId;
  }

  bool get canReceivePhoto {
    return person?.canReceivePhotos ?? false;
  }

  int get displayConfidence {
    final double normalized =
        score.clamp(0.0, 1.0);

    return (normalized * 100).round();
  }

  @override
  String toString() {
    return 'FaceMatchResult('
        'faceIndex: $faceIndex, '
        'person: ${person?.name ?? 'Unknown'}, '
        'score: $score, '
        'recognized: $isRecognized'
        ')';
  }
}