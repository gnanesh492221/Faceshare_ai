import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharingPermissionService {
  SharingPermissionService._();

  static final SharingPermissionService instance =
      SharingPermissionService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<void> setSharingEnabled(bool enabled) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'sharingEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> getSharingEnabled() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!document.exists) {
      return false;
    }

    final data = document.data();

    return data?['sharingEnabled'] == true;
  }
}