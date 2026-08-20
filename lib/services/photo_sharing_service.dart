import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../person.dart';
import '../sharing_history.dart';

import 'sharing_storage.dart';

class PhotoSharingService {
  PhotoSharingService._();

  static final PhotoSharingService instance =
      PhotoSharingService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _firebaseStorage =
      FirebaseStorage.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final SharingStorage _sharingStorage =
      SharingStorage.instance;

  // ============================================================
  // SHARE PHOTO WITH ONE PERSON
  // ============================================================

  Future<bool> sharePhoto({
    required String imagePath,
    required Person person,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        print('FACESHARE: Sender is not logged in.');
        return false;
      }

      if (!person.sharingEnabled) {
        print(
          'FACESHARE: ${person.name} has disabled sharing.',
        );
        return false;
      }

      if (person.faceShareUserId.isEmpty) {
        print(
          'FACESHARE: ${person.name} has no FaceShare ID.',
        );
        return false;
      }

      final File file = File(imagePath);

      if (!await file.exists()) {
        print('FACESHARE: Image does not exist.');
        return false;
      }

      if (await file.length() <= 0) {
        print('FACESHARE: Image is empty.');
        return false;
      }

      final String photoId =
          '${currentUser.uid}_${DateTime.now().microsecondsSinceEpoch}';

      final String storagePath =
          'shared_photos/'
          '${person.faceShareUserId}/'
          '$photoId.jpg';

      final DateTime now = DateTime.now();

      // ========================================================
      // UPLOAD IMAGE
      // ========================================================

      print(
        'FACESHARE: Uploading photo for ${person.name}',
      );

      final Reference reference =
          _firebaseStorage.ref().child(storagePath);

      final UploadTask uploadTask =
          reference.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final TaskSnapshot snapshot =
          await uploadTask;

      final String imageUrl =
          await snapshot.ref.getDownloadURL();

      print(
        'FACESHARE: Image uploaded successfully.',
      );

      // ========================================================
      // CREATE FIRESTORE MESSAGE
      // ========================================================

      await _firestore
          .collection('shared_photos')
          .doc(photoId)
          .set({
        'photoId': photoId,

        // Sender
        'senderUid': currentUser.uid,

        // Receiver
        'receiverFaceShareId':
            person.faceShareUserId,

        'receiverName':
            person.name,

        // Image
        'imageUrl': imageUrl,

        'storagePath': storagePath,

        // Message status
        'status': 'shared',

        'read': false,

        'createdAt':
            FieldValue.serverTimestamp(),
      });

      print(
        'FACESHARE: Firestore message created.',
      );

      // ========================================================
      // SAVE SENDER HISTORY
      // ========================================================

      try {
        await _sharingStorage.initialize();

        await _sharingStorage.addHistory(
          SharingHistory(
            id: photoId,
            imagePath: imagePath,
            sharedWith: [
              person.name,
            ],
            createdAt: now,
          ),
        );
      } catch (e) {
        print(
          'FACESHARE: History save error: $e',
        );
      }

      print(
        'FACESHARE: Photo successfully shared with ${person.name}',
      );

      return true;
    } catch (e) {
      print(
        'FACESHARE: Share error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // SHARE WITH MULTIPLE PEOPLE
  // ============================================================

  Future<int> sharePhotoWithPeople({
    required String imagePath,
    required List<Person> people,
  }) async {
    if (people.isEmpty) {
      return 0;
    }

    final Map<String, Person> uniquePeople = {};

    for (final Person person in people) {
      if (!person.canReceivePhotos) {
        continue;
      }

      uniquePeople[
          person.faceShareUserId] = person;
    }

    int successfulShares = 0;

    for (final Person person
        in uniquePeople.values) {
      final bool success =
          await sharePhoto(
        imagePath: imagePath,
        person: person,
      );

      if (success) {
        successfulShares++;
      }
    }

    return successfulShares;
  }

  // ============================================================
  // DOWNLOAD RECEIVED PHOTO
  // ============================================================

  Future<String> downloadReceivedPhoto({
    required String photoId,
    required String imageUrl,
  }) async {
    final Directory appDirectory =
        await getApplicationDocumentsDirectory();

    final Directory receivedDirectory =
        Directory(
      '${appDirectory.path}/faceshare_received',
    );

    if (!await receivedDirectory.exists()) {
      await receivedDirectory.create(
        recursive: true,
      );
    }

    final File localFile =
        File(
      '${receivedDirectory.path}/$photoId.jpg',
    );

    // Already downloaded.
    if (await localFile.exists()) {
      return localFile.path;
    }

    print(
      'FACESHARE: Downloading received photo $photoId',
    );

    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request =
          await client.getUrl(
        Uri.parse(imageUrl),
      );

      final HttpClientResponse response =
          await request.close();

      if (response.statusCode != 200) {
        throw Exception(
          'Image download failed: '
          '${response.statusCode}',
        );
      }

      final List<int> bytes =
          await response.fold<List<int>>(
        <int>[],
        (previous, chunk) =>
            previous..addAll(chunk),
      );

      await localFile.writeAsBytes(bytes);

      print(
        'FACESHARE: Photo downloaded successfully.',
      );

      return localFile.path;
    } finally {
      client.close();
    }
  }

  // ============================================================
  // MARK PHOTO AS READ
  // ============================================================

  Future<void> markPhotoAsRead(
    String photoId,
  ) async {
    try {
      await _firestore
          .collection('shared_photos')
          .doc(photoId)
          .update({
        'read': true,
        'readAt':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print(
        'FACESHARE: Unable to mark photo as read: $e',
      );
    }
  }

  // ============================================================
  // DELETE CLOUD PHOTO
  // ============================================================

  Future<void> deleteCloudPhoto(
    String photoId,
    String storagePath,
  ) async {
    try {
      await _firestore
          .collection('shared_photos')
          .doc(photoId)
          .delete();

      if (storagePath.isNotEmpty) {
        try {
          await _firebaseStorage
              .ref()
              .child(storagePath)
              .delete();
        } catch (_) {
          // Storage file may already be deleted.
        }
      }
    } catch (e) {
      print(
        'FACESHARE: Cloud delete error: $e',
      );
    }
  }
}
