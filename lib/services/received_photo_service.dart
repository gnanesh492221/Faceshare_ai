import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../received_photo.dart';
import 'received_storage.dart';

class ReceivedPhotoService {
  ReceivedPhotoService._();

  static final ReceivedPhotoService instance =
      ReceivedPhotoService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final ReceivedStorage _receivedStorage =
      ReceivedStorage.instance;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    await _receivedStorage.initialize();
  }

  // ============================================================
  // SYNC RECEIVED PHOTOS
  // ============================================================

  Future<int> syncReceivedPhotos({
    required String faceShareUserId,
  }) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'User is not logged in.',
      );
    }

    if (faceShareUserId.isEmpty) {
      throw StateError(
        'FaceShare user ID is empty.',
      );
    }

    await _receivedStorage.initialize();

    // ----------------------------------------------------------
    // FIND PHOTOS FOR THIS USER
    // ----------------------------------------------------------

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _firestore
            .collection('shared_photos')
            .where(
              'receiverFaceShareId',
              isEqualTo: faceShareUserId,
            )
            .get();

    int downloadedCount = 0;

    // ----------------------------------------------------------
    // PROCESS EACH PHOTO
    // ----------------------------------------------------------

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>> document
        in snapshot.docs) {
      try {
        final Map<String, dynamic> data =
            document.data();

        final String photoId =
            data['photoId']?.toString() ??
                document.id;

        if (photoId.isEmpty) {
          continue;
        }

        // Already downloaded?
        if (_receivedStorage.contains(photoId)) {
          continue;
        }

        final String imageUrl =
            data['imageUrl']?.toString() ?? '';

        final String senderUid =
            data['senderUid']?.toString() ?? '';

        final String senderName =
            data['senderName']?.toString() ??
                'FaceShare user';

        if (imageUrl.isEmpty) {
          continue;
        }

        // ------------------------------------------------------
        // DOWNLOAD IMAGE
        // ------------------------------------------------------

        final Directory directory =
            await _receivedStorage
                .getStorageDirectory();

        final String filePath =
            '${directory.path}/$photoId.jpg';

        final File file =
            File(filePath);

        final Reference storageReference =
            _storage.refFromURL(imageUrl);

        final Uint8List? bytes =
            await storageReference
                .getData(20 * 1024 * 1024);

        if (bytes == null ||
            bytes.isEmpty) {
          continue;
        }

        await file.writeAsBytes(
          bytes,
          flush: true,
        );

        // ------------------------------------------------------
        // CREATED TIME
        // ------------------------------------------------------

        final Timestamp? timestamp =
            data['createdAt']
                as Timestamp?;

        final DateTime receivedAt =
            timestamp?.toDate() ??
                DateTime.now();

        // ------------------------------------------------------
        // SAVE LOCALLY
        // ------------------------------------------------------

        final ReceivedPhoto receivedPhoto =
            ReceivedPhoto(
          id: photoId,
          imagePath: filePath,
          senderName: senderName,
          senderUid: senderUid,
          receivedAt: receivedAt,
          isRead: false,
        );

        await _receivedStorage.addPhoto(
          receivedPhoto,
        );

        // ------------------------------------------------------
        // UPDATE FIRESTORE
        // ------------------------------------------------------

        await document.reference.update({
          'read': true,
          'receivedByUid':
              currentUser.uid,
          'receivedAt':
              FieldValue.serverTimestamp(),
        });

        downloadedCount++;

        print(
          'FACESHARE RECEIVER: '
          'Downloaded $photoId',
        );
      } catch (e) {
        print(
          'FACESHARE RECEIVER: '
          'Failed to download ${document.id}: $e',
        );
      }
    }

    return downloadedCount;
  }

  // ============================================================
  // GET RECEIVED PHOTOS
  // ============================================================

  List<ReceivedPhoto> getPhotos() {
    return _receivedStorage.getPhotos();
  }

  // ============================================================
  // UNREAD COUNT
  // ============================================================

  int get unreadCount {
    return _receivedStorage.unreadCount;
  }

  // ============================================================
  // MARK AS READ
  // ============================================================

  Future<void> markAsRead(String id) async {
    await _receivedStorage.markAsRead(id);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deletePhoto(String id) async {
    await _receivedStorage.deletePhoto(id);
  }
}