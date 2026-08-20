import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path_provider/path_provider.dart';

import '../received_photo.dart';
import 'received_storage.dart';

class PhotoReceiverService {
  PhotoReceiverService._();

  static final PhotoReceiverService instance =
      PhotoReceiverService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final ReceivedStorage _receivedStorage =
      ReceivedStorage.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _subscription;

  bool _running = false;

  // ============================================================
  // START LISTENING
  // ============================================================

  Future<void> startListening({
    required String faceShareUserId,
  }) async {
    if (_running) {
      return;
    }

    if (faceShareUserId.isEmpty) {
      print(
        'RECEIVER: FaceShare ID is empty.',
      );
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      print(
        'RECEIVER: User is not logged in.',
      );
      return;
    }

    await _receivedStorage.initialize();

    _running = true;

    print(
      '================================================',
    );

    print(
      'FACESHARE RECEIVER STARTED',
    );

    print(
      'FaceShare ID: $faceShareUserId',
    );

    // ==========================================================
    // FIRESTORE LISTENER
    // ==========================================================

    _subscription = _firestore
        .collection('shared_photos')
        .where(
          'receiverFaceShareId',
          isEqualTo: faceShareUserId,
        )
        .where(
          'status',
          isEqualTo: 'shared',
        )
        .snapshots()
        .listen(
      (snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type ==
              DocumentChangeType.added) {
            await _processPhoto(
              change.doc,
            );
          }
        }
      },
      onError: (error) {
        print(
          'RECEIVER FIRESTORE ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // PROCESS RECEIVED PHOTO
  // ============================================================

  Future<void> _processPhoto(
 DocumentSnapshot<Map<String, dynamic>>
  ) async {
    try {
      final Map<String, dynamic> data =
          document.data();

      final String photoId =
          data['photoId']?.toString() ??
              document.id;

      final String imageUrl =
          data['imageUrl']?.toString() ?? '';

      final String senderUid =
          data['senderUid']?.toString() ?? '';

      final String senderName =
          data['senderName']?.toString() ??
              'FaceShare User';

      if (photoId.isEmpty ||
          imageUrl.isEmpty) {
        print(
          'RECEIVER: Invalid photo record.',
        );
        return;
      }

      // ----------------------------------------------------------
      // ALREADY RECEIVED?
      // ----------------------------------------------------------

      if (_receivedStorage.contains(photoId)) {
        print(
          'RECEIVER: Photo already exists: $photoId',
        );

        return;
      }

      print(
        'RECEIVER: New photo detected.',
      );

      print(
        'Photo ID: $photoId',
      );

      print(
        'Sender: $senderName',
      );

      // ==========================================================
      // DOWNLOAD IMAGE
      // ==========================================================

      final Directory directory =
          await _receivedStorage
              .getStorageDirectory();

      final String filePath =
          '${directory.path}/$photoId.jpg';

      final File file =
          File(filePath);

      print(
        'RECEIVER: Downloading image...',
      );

      final HttpClient httpClient =
          HttpClient();

      try {
        final HttpClientRequest request =
            await httpClient.getUrl(
          Uri.parse(imageUrl),
        );

        final HttpClientResponse response =
            await request.close();

        if (response.statusCode != 200) {
          print(
            'RECEIVER: Download failed. '
            'Status: ${response.statusCode}',
          );

          return;
        }

        final List<int> bytes =
            await response.fold<List<int>>(
          <int>[],
          (
            List<int> previous,
            List<int> chunk,
          ) {
            return <int>[
              ...previous,
              ...chunk,
            ];
          },
        );

        if (bytes.isEmpty) {
          print(
            'RECEIVER: Downloaded image is empty.',
          );

          return;
        }

        await file.writeAsBytes(
          bytes,
          flush: true,
        );
      } finally {
        httpClient.close();
      }

      // ==========================================================
      // SAVE RECEIVED PHOTO LOCALLY
      // ==========================================================

      final DateTime receivedAt =
          DateTime.now();

      final ReceivedPhoto receivedPhoto =
          ReceivedPhoto(
        id: photoId,
        imagePath: filePath,
        senderName: senderName,
        senderUid: senderUid,
        receivedAt: receivedAt,
      );

      await _receivedStorage.addPhoto(
        receivedPhoto,
      );

      // ==========================================================
      // MARK FIRESTORE RECORD AS RECEIVED
      // ==========================================================

      try {
        await document.reference.update({
          'status': 'received',
          'read': false,
          'receivedAt':
              FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print(
          'RECEIVER: Unable to update status: $e',
        );
      }

      print(
        'RECEIVER: Photo saved successfully.',
      );

      print(
        'Local path: $filePath',
      );

      print(
        '================================================',
      );
    } catch (e) {
      print(
        'RECEIVER PROCESSING ERROR: $e',
      );
    }
  }

  // ============================================================
  // STOP LISTENING
  // ============================================================

  Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;
    _running = false;

    print(
      'FACESHARE RECEIVER STOPPED',
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await stopListening();
  }
}