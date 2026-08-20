import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceShareIdService {
  FaceShareIdService._();

  static final FaceShareIdService instance =
      FaceShareIdService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<String> createOrGetFaceShareId() async {
    // Make sure the user is signed in.
    User? user = _auth.currentUser;

    if (user == null) {
      final credential =
          await _auth.signInAnonymously();

      user = credential.user;
    }

    if (user == null) {
      throw Exception(
        'Unable to create Firebase user.',
      );
    }

    final userRef =
        _firestore.collection('users').doc(user.uid);

    final existing =
        await userRef.get();

    // If an ID already exists, reuse it.
    if (existing.exists) {
      final data = existing.data();

      final existingId =
          data?['faceShareUserId'];

      if (existingId is String &&
          existingId.isNotEmpty) {
        return existingId;
      }
    }

    // Generate a new ID.
    final faceShareId =
        _generateFaceShareId();

    await userRef.set(
      {
        'faceShareUserId': faceShareId,
        'firebaseUid': user.uid,
        'sharingEnabled': true,
        'createdAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return faceShareId;
  }

  String _generateFaceShareId() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random();

    final code = List.generate(
      6,
      (_) => characters[
          random.nextInt(
            characters.length,
          )],
    ).join();

    return 'FS-$code';
  }
}